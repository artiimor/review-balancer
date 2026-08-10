import { Controller } from "@hotwired/stimulus"

// Connect to data-controller="theme"
export default class extends Controller {
  toggle() {
    const next = document.documentElement.classList.contains("dark") ? "light" : "dark"

    localStorage.setItem("theme", next)
    document.documentElement.classList.toggle("dark", next === "dark")
  }
}
