import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="error-message"
export default class extends Controller {
  connect() {
    var self = this;

    setTimeout(function() {
      self.element.remove();
    }, 5000);
  }
}
