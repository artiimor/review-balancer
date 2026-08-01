import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    self = this;
  }

  close(){
    this.element.classList.add("hidden")
  }
}
