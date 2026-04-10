// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
import Chart from "chart.js/auto"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

const formatMetric = (value, format = "quantity") => {
  const numericValue = typeof value === "number" ? value : Number(value || 0)

  if (format === "integer") {
    return new Intl.NumberFormat("en-KE", {maximumFractionDigits: 0}).format(numericValue)
  }

  const formatted = new Intl.NumberFormat("en-KE", {
    minimumFractionDigits: 1,
    maximumFractionDigits: 1
  }).format(numericValue)

  return format === "kes" ? `KES ${formatted}` : formatted
}

const applyChartFormatting = (config) => {
  const valueFormats = config.valueFormats || {}
  const options = config.options || {}
  const scales = options.scales || {}

  Object.entries(scales).forEach(([axis, axisConfig]) => {
    const axisFormat = valueFormats[axis]

    if (!axisFormat) return

    axisConfig.ticks = axisConfig.ticks || {}
    axisConfig.ticks.callback = (value) => formatMetric(value, axisFormat)
  })

  const tooltipCallbacks = options.plugins?.tooltip?.callbacks || {}

  return {
    ...config,
    options: {
      responsive: true,
      maintainAspectRatio: false,
      ...options,
      scales,
      plugins: {
        legend: {
          labels: {
            usePointStyle: true,
            boxWidth: 10,
            color: "#1f2a16"
          },
          ...options.plugins?.legend
        },
        tooltip: {
          ...options.plugins?.tooltip,
          callbacks: {
            ...tooltipCallbacks,
            label: (context) => {
              const datasetFormat = context.dataset.valueFormat
              const axisFormat = valueFormats[context.dataset.yAxisID || "y"]
              const selectedFormat = datasetFormat || axisFormat || config.valueFormat || "quantity"
              const rawValue = context.parsed.y ?? context.parsed
              const prefix = context.dataset.label ? `${context.dataset.label}: ` : ""

              return prefix + formatMetric(rawValue, selectedFormat)
            }
          }
        }
      }
    }
  }
}

const Hooks = {
  ChartRenderer: {
    mounted() {
      this.renderChart()
    },

    updated() {
      this.renderChart()
    },

    destroyed() {
      if (this.chart) this.chart.destroy()
    },

    renderChart() {
      const payload = this.el.dataset.chart
      if (!payload) return

      const config = applyChartFormatting(JSON.parse(payload))

      if (this.chart) this.chart.destroy()
      this.chart = new Chart(this.el, config)
    }
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#5d9138"}, shadowColor: "rgba(93, 145, 56, 0.35)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

