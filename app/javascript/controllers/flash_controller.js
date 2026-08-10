import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flash"
export default class extends Controller {
  static values = { delay: { type: Number, default: 6000 } }

  connect() {
    setTimeout(() => this.element.remove(), this.delayValue)
  }
}
