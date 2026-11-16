export function closeOnMorph(dialog, event) {
  if (event.target === dialog && event.detail.attributeName === "open") {
    event.preventDefault()
    dialog.close()
  }
}
