import { Controller } from "@hotwired/stimulus"

// Opens a dialog elsewhere on the page, named by id.
export default class extends Controller {
  open({ params: { id } }) {
    document.getElementById(id)?.showModal()
  }
}
