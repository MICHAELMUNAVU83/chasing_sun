defmodule ChasingSun.Operations.AgronomicVisit do
  use Ecto.Schema
  import Ecto.Changeset

  schema "agronomic_visits" do
    field :visited_on, :date
    field :agronomist_name, :string
    field :summary, :string
    field :report_file_url, :string
    field :report_file_name, :string
    field :content_type, :string
    field :byte_size, :integer

    belongs_to :inserted_by_user, ChasingSun.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(visit, attrs) do
    visit
    |> cast(attrs, [
      :visited_on,
      :agronomist_name,
      :summary,
      :report_file_url,
      :report_file_name,
      :content_type,
      :byte_size,
      :inserted_by_user_id
    ])
    |> validate_required([:visited_on, :agronomist_name, :report_file_url])
    |> validate_length(:agronomist_name, max: 200)
    |> validate_not_future(:visited_on)
    |> unique_constraint(:visited_on,
      message: "an agronomic visit is already recorded for this date"
    )
  end

  defp validate_not_future(changeset, field) do
    validate_change(changeset, field, fn ^field, date ->
      if Date.compare(date, Date.utc_today()) == :gt do
        [{field, "cannot be in the future"}]
      else
        []
      end
    end)
  end
end
