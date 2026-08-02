import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="disclosure"
export default class extends Controller {
  static targets = ["panel", "label"]

  toggle() {
    const hidden = this.panelTarget.classList.toggle("hidden")

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = hidden ? this.labelTarget.dataset.showText : this.labelTarget.dataset.hideText
    }
  }
}
