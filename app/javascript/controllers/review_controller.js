import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "answerText", "elapsed", "attempts", "backspaces", "timer"]
  static values = {
    answer: String,
    audioUrl: { type: String, default: "" }
  }

  connect() {
    this.startedAt = Date.now()
    this.attemptCount = 0
    this.backspaceCount = 0
    this.firstAnswerRecorded = false
    this.readyToSubmit = false
    this.submitting = false
    this.audioBuffer = null
    this.audioContext = null
    this.audioSource = null
    this.timerInterval = null
    this._originalPlaceholder = this.inputTarget.placeholder

    this.inputTarget.focus()
    this.resizeInput()
    this.preloadAudio()
    this.startTimer()
  }

  disconnect() {
    this.stopTimer()

    if (!this.audioSource) return

    this.audioSource.onended = null
    this.audioSource.stop()
    this.audioSource = null
  }

  startTimer() {
    this.updateTimer()
    this.timerInterval = setInterval(() => this.updateTimer(), 1000)
  }

  stopTimer() {
    if (this.timerInterval) {
      clearInterval(this.timerInterval)
      this.timerInterval = null
    }
  }

  updateTimer() {
    if (!this.hasTimerTarget) return

    const elapsed = Date.now() - this.startedAt
    const minutes = Math.floor(elapsed / 60000)
    const seconds = Math.floor((elapsed % 60000) / 1000)

    this.timerTarget.textContent =
      String(minutes).padStart(2, "0") + ":" + String(seconds).padStart(2, "0")
  }

  onInput() {
    const typed = this.inputTarget.value.toLowerCase()
    const expected = this.answerValue
    this.resizeInput()

    if (typed.length > 0) {
      this.inputTarget.placeholder = ""
    }

    const tertiary = getComputedStyle(document.documentElement).getPropertyValue('--color-tertiary').trim()
    const errorColor = getComputedStyle(document.documentElement).getPropertyValue('--color-error').trim()
    const outlineVariant = getComputedStyle(document.documentElement).getPropertyValue('--color-outline-variant').trim()

    if (typed.length === 0) {
      this.inputTarget.style.borderBottomColor = outlineVariant
    } else if (expected.startsWith(typed)) {
      this.inputTarget.style.borderBottomColor = tertiary
    } else {
      this.inputTarget.style.borderBottomColor = errorColor
    }
  }

  trackKey(event) {
    if (event.key === "Backspace") {
      this.backspaceCount++
    } else if (event.key === "Enter") {
      event.preventDefault()
      this.submit(event)
    }
  }

  async submit(event) {
    if (this.readyToSubmit) {
      this.readyToSubmit = false
      return
    }

    event.preventDefault()
    if (this.submitting) return

    const userAnswer = this.inputTarget.value.trim()
    const isCorrect = userAnswer.toLowerCase() === this.answerValue

    if (!this.firstAnswerRecorded) {
      this.answerTextTarget.value = userAnswer
      this.firstAnswerRecorded = true
    }

    this.attemptCount++

    if (isCorrect) {
      this.submitting = true
      this.inputTarget.disabled = true
      await this.playAudioThenSubmit()
    } else {
      this.resetUIForRetry()
    }
  }

  resetUIForRetry() {
    this.inputTarget.value = ""
    this.inputTarget.placeholder = this.answerValue

    const primary = getComputedStyle(document.documentElement).getPropertyValue('--color-primary').trim()
    this.inputTarget.style.borderBottomColor = primary

    this.inputTarget.focus()
  }

  finalSubmit() {
    this.elapsedTarget.value = Date.now() - this.startedAt
    this.attemptsTarget.value = this.attemptCount
    this.backspacesTarget.value = this.backspaceCount
    this.readyToSubmit = true
    this.element.querySelector("form").requestSubmit()
  }

  async preloadAudio() {
    if (!this.audioUrlValue) return

    try {
      this.audioContext = this.audioContext || new AudioContext()
      const response = await fetch(this.audioUrlValue)
      if (!response.ok) return

      const arrayBuffer = await response.arrayBuffer()
      this.audioBuffer = await this.audioContext.decodeAudioData(arrayBuffer)
    } catch {
      // Audio unavailable — silent fallback
    }
  }

  async triggerAudio() {
    if (!this.audioBuffer || !this.audioContext) return

    try {
      if (this.audioContext.state === "suspended") {
        await this.audioContext.resume()
      }

      if (this.audioSource) {
        this.audioSource.onended = null
        this.audioSource.stop()
      }

      const source = this.audioContext.createBufferSource()
      this.audioSource = source
      source.buffer = this.audioBuffer
      source.connect(this.audioContext.destination)
      source.onended = () => {
        if (this.audioSource === source) this.audioSource = null
      }
      source.start(0)
    } catch {
      // Audio unavailable — silent fallback
    }
  }

  async playAudioThenSubmit() {
    const playbackStarted = await this.playAudio()

    if (!playbackStarted) {
      this.finalSubmit()
    }
  }

  async playAudio() {
    if (!this.audioBuffer || !this.audioContext) return false

    try {
      if (this.audioContext.state === "suspended") {
        await this.audioContext.resume()
      }

      if (this.audioSource) {
        this.audioSource.onended = null
        this.audioSource.stop()
      }

      const source = this.audioContext.createBufferSource()
      this.audioSource = source
      source.buffer = this.audioBuffer
      source.connect(this.audioContext.destination)
      source.onended = () => {
        if (this.audioSource !== source) return

        this.audioSource = null
        this.finalSubmit()
      }
      source.start(0)

      return true
    } catch {
      this.audioSource = null
      return false
    }
  }

  resizeInput() {
    const canvas = document.createElement("canvas")
    const ctx = canvas.getContext("2d")
    const style = getComputedStyle(this.inputTarget)
    ctx.font = style.font
    const width = ctx.measureText(this.answerValue).width
    this.inputTarget.style.width = `${Math.max(width + 48, 140)}px`
  }
}
