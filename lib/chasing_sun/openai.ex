defmodule ChasingSun.OpenAI do
  @moduledoc false

  require Logger

  @api_url "https://api.openai.com/v1/responses"
  @default_model "gpt-4o-mini"

  def extract_harvest_from_pickup_note(image_attrs, greenhouses, opts \\ []) do
    with {:ok, api_key} <- api_key(),
         {:ok, data_url} <- data_url(image_attrs),
         {:ok, response_body} <- request(api_key, request_body(data_url, greenhouses, opts)),
         {:ok, payload} <- decode_payload(response_body) do
      {:ok, normalize_payload(payload, greenhouses)}
    end
  end

  defp api_key do
    # config = Application.get_env(:chasing_sun, __MODULE__, [])

    # case Keyword.get(config, :api_key) || System.get_env("OPENAI_API_KEY") do
    #   key when is_binary(key) and byte_size(key) > 0 -> {:ok, key}
    #   _ -> {:error, "OPENAI_API_KEY is not configured."}
    # end
  end

  defp request(api_key, body) do
    case Req.post(@api_url,
           headers: [
             {"authorization", "Bearer #{api_key}"},
             {"content-type", "application/json"}
           ],
           json: body,
           receive_timeout: 60_000
         ) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %Req.Response{status: status, body: response_body}} ->
        Logger.warning("OpenAI pickup-note request failed: #{status} #{inspect(response_body)}")
        {:error, "OpenAI could not analyze this pickup note right now."}

      {:error, reason} ->
        Logger.warning("OpenAI pickup-note request errored: #{inspect(reason)}")
        {:error, "OpenAI could not analyze this pickup note right now."}
    end
  end

  defp request_body(data_url, greenhouses, opts) do
    %{
      "model" => model(opts),
      "input" => [
        %{
          "role" => "system",
          "content" => [
            %{"type" => "input_text", "text" => system_prompt()}
          ]
        },
        %{
          "role" => "user",
          "content" => [
            %{"type" => "input_text", "text" => user_prompt(greenhouses)},
            %{"type" => "input_image", "image_url" => data_url}
          ]
        }
      ],
      "max_output_tokens" => 400,
      "text" => %{
        "format" => %{
          "type" => "json_schema",
          "name" => "pickup_note_harvest",
          "strict" => true,
          "schema" => response_schema()
        }
      }
    }
  end

  defp model(opts) do
    config = Application.get_env(:chasing_sun, __MODULE__, [])

    Keyword.get(opts, :model) ||
      Keyword.get(config, :model) ||
      System.get_env("CHASING_SUN_OPENAI_MODEL") ||
      @default_model
  end

  defp system_prompt do
    """
    You extract greenhouse harvest data from pickup note images for a greenhouse operations app.
    Read the image carefully and return only the schema requested.

    Rules:
    - Choose greenhouse_id only from the provided greenhouse catalog.
    - Use the exact greenhouse_id from the catalog when you can identify the greenhouse from the note.
    - If the greenhouse is unclear, return an empty greenhouse_id and explain briefly in explanation.
    - Return actual_yield as a numeric value only, without units.
    - If the image does not clearly contain a harvest quantity, set found_harvest_data to false and actual_yield to 0.
    - If a date is visible, return it as YYYY-MM-DD. If not visible, return an empty string.
    - Keep notes short and factual.
    """
  end

  defp user_prompt(greenhouses) do
    greenhouse_catalog =
      greenhouses
      |> Enum.map(fn greenhouse ->
        %{
          greenhouse_id: greenhouse.id,
          greenhouse_name: greenhouse.name,
          greenhouse_sequence_no: greenhouse.sequence_no,
          venture_code: greenhouse.venture.code,
          venture_name: greenhouse.venture.name
        }
      end)
      |> Jason.encode!()

    """
    Match the pickup note image against this greenhouse catalog:
    #{greenhouse_catalog}
    """
  end

  defp response_schema do
    %{
      "type" => "object",
      "additionalProperties" => false,
      "required" => [
        "found_harvest_data",
        "greenhouse_id",
        "greenhouse_name",
        "greenhouse_sequence_no",
        "venture_code",
        "actual_yield",
        "week_ending_on",
        "notes",
        "confidence",
        "explanation"
      ],
      "properties" => %{
        "found_harvest_data" => %{"type" => "boolean"},
        "greenhouse_id" => %{"type" => "string"},
        "greenhouse_name" => %{"type" => "string"},
        "greenhouse_sequence_no" => %{"type" => "string"},
        "venture_code" => %{"type" => "string"},
        "actual_yield" => %{"type" => "number"},
        "week_ending_on" => %{"type" => "string"},
        "notes" => %{"type" => "string"},
        "confidence" => %{"type" => "number"},
        "explanation" => %{"type" => "string"}
      }
    }
  end

  defp data_url(%{binary: binary, mime_type: mime_type})
       when is_binary(binary) and is_binary(mime_type) do
    {:ok, "data:#{mime_type};base64,#{Base.encode64(binary)}"}
  end

  defp data_url(%{path: path, mime_type: mime_type}) do
    with {:ok, binary} <- File.read(path) do
      {:ok, "data:#{mime_type};base64,#{Base.encode64(binary)}"}
    end
  end

  defp decode_payload(response_body) do
    case response_text(response_body) do
      nil ->
        {:error, "OpenAI returned an empty response for this pickup note."}

      text ->
        case Jason.decode(text) do
          {:ok, payload} ->
            {:ok, payload}

          {:error, _reason} ->
            {:error, "OpenAI returned an unreadable response for this pickup note."}
        end
    end
  end

  defp response_text(%{"output_text" => text}) when is_binary(text) and byte_size(text) > 0,
    do: text

  defp response_text(%{"output" => output}) when is_list(output) do
    output
    |> Enum.flat_map(fn
      %{"content" => content} when is_list(content) -> content
      _ -> []
    end)
    |> Enum.find_value(fn
      %{"type" => "output_text", "text" => text} when is_binary(text) and byte_size(text) > 0 ->
        text

      _ ->
        nil
    end)
  end

  defp response_text(_response_body), do: nil

  defp normalize_payload(payload, greenhouses) do
    greenhouse = match_greenhouse(payload, greenhouses)
    actual_yield = parse_float(payload["actual_yield"])
    week_ending_on = parse_date(payload["week_ending_on"])
    notes = payload["notes"] |> sanitize_text() |> fallback_text(payload["explanation"])

    %{
      "found_harvest_data" => payload["found_harvest_data"] == true,
      "greenhouse_id" => if(greenhouse, do: to_string(greenhouse.id), else: ""),
      "actual_yield" => if(actual_yield > 0, do: actual_yield, else: ""),
      "week_ending_on" => if(week_ending_on, do: Date.to_iso8601(week_ending_on), else: ""),
      "notes" => notes,
      "confidence" => parse_float(payload["confidence"]),
      "greenhouse_name" =>
        if(greenhouse, do: greenhouse.name, else: sanitize_text(payload["greenhouse_name"])),
      "explanation" => sanitize_text(payload["explanation"])
    }
  end

  defp match_greenhouse(payload, greenhouses) do
    greenhouse_id = sanitize_text(payload["greenhouse_id"])
    greenhouse_name = normalize_text(payload["greenhouse_name"])
    sequence_no = sanitize_text(payload["greenhouse_sequence_no"])
    venture_code = normalize_text(payload["venture_code"])

    Enum.find(greenhouses, &(to_string(&1.id) == greenhouse_id)) ||
      Enum.find(greenhouses, &(normalize_text(&1.name) == greenhouse_name)) ||
      match_by_sequence(greenhouses, sequence_no, venture_code)
  end

  defp match_by_sequence(_greenhouses, "", _venture_code), do: nil

  defp match_by_sequence(greenhouses, sequence_no, venture_code) do
    matches =
      Enum.filter(greenhouses, fn greenhouse ->
        to_string(greenhouse.sequence_no) == sequence_no and
          (venture_code == "" or normalize_text(greenhouse.venture.code) == venture_code)
      end)

    case matches do
      [greenhouse] -> greenhouse
      _ -> nil
    end
  end

  defp parse_float(value) when is_float(value), do: Float.round(value, 1)
  defp parse_float(value) when is_integer(value), do: value * 1.0

  defp parse_float(value) when is_binary(value) do
    value
    |> String.replace(~r/[^0-9.]/, "")
    |> case do
      "" ->
        0.0

      cleaned ->
        case Float.parse(cleaned) do
          {parsed, _rest} -> Float.round(parsed, 1)
          :error -> 0.0
        end
    end
  end

  defp parse_float(_value), do: 0.0

  defp parse_date(value) when is_binary(value) and byte_size(value) > 0 do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_date(_value), do: nil

  defp sanitize_text(value) when is_binary(value), do: String.trim(value)
  defp sanitize_text(_value), do: ""

  defp fallback_text("", fallback), do: sanitize_text(fallback)
  defp fallback_text(text, _fallback), do: text

  defp normalize_text(value), do: value |> sanitize_text() |> String.downcase()
end
