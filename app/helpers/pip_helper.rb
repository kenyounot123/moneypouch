module PipHelper
  PIP_EYES = {
    idle: "M7 13h1v2h-1zM12 13h1v2h-1z",
    shut: "M6 14h2v1h-2zM12 14h2v1h-2z",
    happy: "M7 13h1v1h-1zM12 13h1v1h-1zM6 14h1v1h-1zM8 14h1v1h-1zM11 14h1v1h-1zM13 14h1v1h-1z",
    worried: "M7 11h1v1h-1zM12 11h1v1h-1zM6 12h1v1h-1zM13 12h1v1h-1zM7 13h1v2h-1zM12 13h1v2h-1z"
  }.freeze

  def pip_eyes(pose)
    PIP_EYES.fetch(pose)
  end
end
