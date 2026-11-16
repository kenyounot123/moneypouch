import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  open({ params: { id } }) {
    document.getElementById(id)?.showModal()
  }
}
