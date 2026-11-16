export class Pointer {
  moved(event) {
    const moved = this.position !== undefined && (this.position.x !== event.screenX || this.position.y !== event.screenY)
    this.position = { x: event.screenX, y: event.screenY }
    return moved
  }
}
