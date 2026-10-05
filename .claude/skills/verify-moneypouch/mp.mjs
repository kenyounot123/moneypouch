#!/usr/bin/env node
import { spawn, spawnSync } from "node:child_process"
import fs from "node:fs"
import net from "node:net"
import path from "node:path"
import { fileURLToPath } from "node:url"

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../../..")
const STATE_ROOT = path.join(ROOT, "tmp/verify")
const sleep = (ms) => new Promise((r) => setTimeout(r, ms))
const die = (msg) => { console.error(`mp: ${msg}`); process.exit(1) }

const onPath = (name) => spawnSync("which", [name], { encoding: "utf8" }).stdout.trim()
const CHROME = process.env.MP_CHROME || [
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  ...["google-chrome", "google-chrome-stable", "chromium", "chromium-browser"].map(onPath),
].find((p) => p && fs.existsSync(p))

const VALUE_FLAGS = new Set(["port", "delay", "text", "timeout", "end", "log", "report"])

const NAMED_KEYS = {
  Enter: { code: "Enter", vk: 13, text: "\r" }, Escape: { code: "Escape", vk: 27 },
  Tab: { code: "Tab", vk: 9 }, Backspace: { code: "Backspace", vk: 8 }, Delete: { code: "Delete", vk: 46 },
  ArrowUp: { code: "ArrowUp", vk: 38 }, ArrowDown: { code: "ArrowDown", vk: 40 },
  ArrowLeft: { code: "ArrowLeft", vk: 37 }, ArrowRight: { code: "ArrowRight", vk: 39 },
  Home: { code: "Home", vk: 36 }, End: { code: "End", vk: 35 },
  PageUp: { code: "PageUp", vk: 33 }, PageDown: { code: "PageDown", vk: 34 },
}
const MODS = { Alt: 1, Control: 2, Ctrl: 2, Meta: 4, Cmd: 4, Shift: 8 }

const PUNCTUATION = [
  ["`~", "Backquote", 192], ["-_", "Minus", 189], ["=+", "Equal", 187], ["[{", "BracketLeft", 219],
  ["]}", "BracketRight", 221], ["\\|", "Backslash", 220], [";:", "Semicolon", 186], ["'\"", "Quote", 222],
  [",<", "Comma", 188], [".>", "Period", 190], ["/?", "Slash", 191],
]
const SHIFTED_DIGITS = ")!@#$%^&*("
const PRINTABLE = new Map([[" ", { code: "Space", vk: 32, shift: false }]])
for (let d = 0; d < 10; d++) {
  PRINTABLE.set(String(d), { code: `Digit${d}`, vk: 48 + d, shift: false })
  PRINTABLE.set(SHIFTED_DIGITS[d], { code: `Digit${d}`, vk: 48 + d, shift: true })
}
for (const [pair, code, vk] of PUNCTUATION) {
  PRINTABLE.set(pair[0], { code, vk, shift: false })
  PRINTABLE.set(pair[1], { code, vk, shift: true })
}
for (let i = 0; i < 26; i++) {
  const lower = String.fromCharCode(97 + i)
  PRINTABLE.set(lower, { code: `Key${lower.toUpperCase()}`, vk: 65 + i, shift: false })
  PRINTABLE.set(lower.toUpperCase(), { code: `Key${lower.toUpperCase()}`, vk: 65 + i, shift: true })
}

function freePort(from = 0) {
  return new Promise((resolve, reject) => {
    const srv = net.createServer()
    srv.once("error", reject)
    srv.listen(from, "127.0.0.1", () => { const { port } = srv.address(); srv.close(() => resolve(port)) })
  })
}
const portFree = (p) => freePort(p).then(() => true, () => false)
const alive = (pid) => { try { process.kill(pid, 0); return true } catch { return false } }
const commandOf = (pid) => spawnSync("ps", ["-o", "command=", "-p", String(pid)], { encoding: "utf8" }).stdout.trim()
const ours = (pid, ...needles) => { if (!pid || !alive(pid)) return false; const cmd = commandOf(pid); return needles.some((n) => cmd.includes(n)) }

const dirFor = (port) => path.join(STATE_ROOT, String(port))
const profileFor = (port) => path.join(dirFor(port), "profile")
const serverNeedles = (port) => [`tcp://127.0.0.1:${port}`, `rails server -b 127.0.0.1 -p ${port} `]
const chromeNeedle = (port) => `--user-data-dir=${profileFor(port)}`
const serverUp = (s, port) => !!s && ours(s.serverPid, ...serverNeedles(port))
const chromeUp = (s, port) => !!s && ours(s.chromePid, chromeNeedle(port))
const readState = (port) => { try { return JSON.parse(fs.readFileSync(path.join(dirFor(port), "state.json"), "utf8")) } catch { return null } }
const writeState = (port, s) => {
  fs.mkdirSync(dirFor(port), { recursive: true })
  const file = path.join(dirFor(port), "state.json")
  const tmp = `${file}.${process.pid}.tmp`
  fs.writeFileSync(tmp, JSON.stringify(s, null, 2))
  fs.renameSync(tmp, file)
}

function liveInstances() {
  const known = fs.existsSync(STATE_ROOT) ? fs.readdirSync(STATE_ROOT).filter((p) => /^\d+$/.test(p)) : []
  return known.filter((p) => serverUp(readState(p), p) || chromeUp(readState(p), p)).map(Number)
}

function parseArgs(argv) {
  const flags = {}, rest = []
  for (let i = 0; i < argv.length; i++) {
    if (!argv[i].startsWith("--")) { rest.push(argv[i]); continue }
    const key = argv[i].slice(2)
    flags[key] = VALUE_FLAGS.has(key) ? (argv[++i] ?? die(`--${key} needs a value`)) : true
  }
  return { flags, rest }
}

function resolvePort(flags) {
  if (flags.port) return Number(flags.port)
  if (process.env.MP_PORT) return Number(process.env.MP_PORT)
  const live = liveInstances()
  if (live.length === 1) return live[0]
  die(live.length ? `several instances running (${live.join(", ")}); pass --port N` : "no instance running; run: mp.mjs boot")
}

async function withLock(fn) {
  fs.mkdirSync(STATE_ROOT, { recursive: true })
  const lock = path.join(STATE_ROOT, "setup.lock")
  const deadline = Date.now() + 300000
  for (;;) {
    const mine = `${lock}.${process.pid}`
    fs.writeFileSync(mine, String(process.pid))
    try { fs.linkSync(mine, lock); fs.rmSync(mine); break } catch {
      fs.rmSync(mine, { force: true })
      let holder
      try { holder = Number(fs.readFileSync(lock, "utf8")) } catch { continue }
      if (!alive(holder)) {
        try { if (Number(fs.readFileSync(lock, "utf8")) === holder) fs.rmSync(lock, { force: true }) } catch {}
        continue
      }
      if (Date.now() > deadline) die(`setup lock ${lock} held by pid ${holder} for over 5 minutes`)
      await sleep(250)
    }
  }
  const release = () => { try { if (Number(fs.readFileSync(lock, "utf8")) === process.pid) fs.rmSync(lock, { force: true }) } catch {} }
  process.on("exit", release)
  try { return await fn() } finally { release() }
}

async function cdpSession(port) {
  const s = readState(port)
  if (!chromeUp(s, port)) die(`no browser for port ${port}; run: mp.mjs boot --port ${port}`)
  const targets = await (await fetch(`http://127.0.0.1:${s.cdpPort}/json/list`, { signal: AbortSignal.timeout(5000) })).json()
  const page = targets.find((t) => t.type === "page")
  const ws = new WebSocket(page.webSocketDebuggerUrl)
  await new Promise((res, rej) => {
    const timer = setTimeout(() => rej(new Error("DevTools socket did not open within 5s")), 5000)
    ws.onopen = () => { clearTimeout(timer); res() }
    ws.onerror = () => { clearTimeout(timer); rej(new Error("could not open the DevTools socket")) }
  })
  let id = 0
  const pending = new Map(), waiters = [], listeners = []
  const failAll = (why) => { for (const { rej } of pending.values()) rej(new Error(why)); pending.clear() }
  ws.onclose = () => failAll("DevTools socket closed")
  ws.onerror = () => failAll("DevTools socket error")
  ws.onmessage = ({ data }) => {
    const m = JSON.parse(data)
    if (m.id && pending.has(m.id)) {
      const { res, rej } = pending.get(m.id)
      pending.delete(m.id)
      m.error ? rej(new Error(m.error.message)) : res(m.result)
    } else if (m.method) {
      waiters.filter((w) => w.method === m.method).forEach((w) => w.res(m.params))
      listeners.filter((l) => l.method === m.method).forEach((l) => l.fn(m.params))
    }
  }
  const send = (method, params = {}, ms = 20000) => new Promise((res, rej) => {
    const i = ++id
    const timer = setTimeout(() => { pending.delete(i); rej(new Error(`${method} timed out after ${ms / 1000}s`)) }, ms)
    pending.set(i, { res: (v) => { clearTimeout(timer); res(v) }, rej: (e) => { clearTimeout(timer); rej(e) } })
    ws.send(JSON.stringify({ id: i, method, params }))
  })
  const once = (method, ms = 15000) => new Promise((res, rej) => {
    const timer = setTimeout(() => rej(new Error(`timeout waiting for ${method}`)), ms)
    waiters.push({ method, res: (p) => { clearTimeout(timer); res(p) } })
  })
  await send("Page.enable")
  const evaluate = async (expression) => {
    const r = await send("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true })
    if (r.exceptionDetails) throw new Error(r.exceptionDetails.exception?.description || r.exceptionDetails.text)
    return r.result.value
  }
  const settle = async () => {
    await sleep(400)
    for (let i = 0; i < 50 && (await evaluate("document.readyState")) !== "complete"; i++) await sleep(100)
  }
  const goto = async (url) => { const loaded = once("Page.loadEventFired"); await send("Page.navigate", { url }); await loaded; await sleep(300) }
  const key = async (spec) => {
    const parts = spec.length > 1 ? spec.split("+") : [spec]
    const name = parts.pop()
    let modifiers = parts.reduce((m, p) => m | (MODS[p] ?? die(`unknown modifier ${p}`)), 0)
    const named = NAMED_KEYS[name]
    const printable = PRINTABLE.get(name)
    if (!named && !printable) die(`unknown key ${name}`)
    if (printable?.shift) modifiers |= 8
    const def = named ?? printable
    const text = modifiers & ~8 ? undefined : named ? named.text : name
    const base = { key: name, code: def.code, windowsVirtualKeyCode: def.vk, modifiers }
    await send("Input.dispatchKeyEvent", { type: text ? "keyDown" : "rawKeyDown", ...base, text })
    await send("Input.dispatchKeyEvent", { type: "keyUp", ...base })
  }
  const typeChar = (ch) => PRINTABLE.has(ch) ? key(ch) : send("Input.insertText", { text: ch })
  const focus = (selector) => evaluate(`(() => { const e = document.querySelector(${JSON.stringify(selector)}); if (!e) return false; e.focus(); return true })()`)
  const click = async (selector) => {
    const box = await evaluate(`(() => { const e = document.querySelector(${JSON.stringify(selector)}); if (!e) return null; e.scrollIntoView({ block: "center" }); const r = e.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 } })()`)
    if (!box) die(`no element matches ${selector} on ${await evaluate("location.href")}`)
    await send("Input.dispatchMouseEvent", { type: "mouseMoved", ...box })
    for (const type of ["mousePressed", "mouseReleased"]) await send("Input.dispatchMouseEvent", { type, ...box, button: "left", clickCount: 1 })
  }
  const on = (method, fn) => listeners.push({ method, fn })
  return { send, evaluate, goto, settle, key, typeChar, focus, click, on, close: () => ws.close() }
}

async function signIn(b, port, user, password) {
  await b.goto(`http://localhost:${port}/`)
  if (!(await b.evaluate("location.pathname")).startsWith("/session")) return
  for (const [selector, value] of [["#username", user], ["#password", password]]) {
    await b.focus(selector)
    await b.send("Input.insertText", { text: value })
  }
  await b.key("Enter")
  for (let i = 0; i < 100; i++) {
    await sleep(100)
    try { if ((await b.evaluate("document.readyState")) === "complete" && (await b.evaluate("location.pathname")) !== "/session/new") break } catch {}
  }
  await b.settle()
}

function demoPassword() {
  const m = fs.readFileSync(path.join(ROOT, "db/seeds.rb"), "utf8").match(/demo_password\s*=\s*"([^"]+)"/)
  return m ? m[1] : die("demo_password not found in db/seeds.rb")
}

function rails(args, env = {}) {
  const r = spawnSync("bin/rails", args, { cwd: ROOT, encoding: "utf8", env: { ...process.env, ...env } })
  if (r.status !== 0) die(`bin/rails ${args[0]} failed\n${(r.stdout + r.stderr).split("\n").slice(0, 2).join("\n")}`)
  return r.stdout
}

const tail = (file, n = 15) => { try { return fs.readFileSync(file, "utf8").split("\n").slice(-n).join("\n") } catch { return "" } }

async function waitUp(port, s) {
  const end = Date.now() + 90000
  while (Date.now() < end) {
    if (!alive(s.serverPid)) die(`server on ${port} exited during startup\n${tail(path.join(dirFor(port), "server.log"))}`)
    try { if ((await fetch(`http://127.0.0.1:${port}/up`)).status === 200) return } catch {}
    await sleep(300)
  }
  die(`server on ${port} did not answer /up within 90s\n${tail(path.join(dirFor(port), "server.log"))}`)
}

async function startServer(port, s) {
  if (!fs.existsSync(path.join(ROOT, "app/assets/builds/tailwind.css"))) rails(["tailwindcss:build"])
  rails(["db:prepare"])
  rails(["db:seed"])
  fs.rmSync(path.join(ROOT, `tmp/pids/verify-${port}.pid`), { force: true })
  const log = fs.openSync(path.join(dirFor(port), "server.log"), "a")
  const server = spawn("bin/rails", ["server", "-b", "127.0.0.1", "-p", String(port), "-P", `tmp/pids/verify-${port}.pid`], { cwd: ROOT, detached: true, stdio: ["ignore", log, log] })
  server.unref()
  return { ...s, serverPid: server.pid }
}

async function startChrome(port, s) {
  if (!CHROME) die("no Chrome found; set MP_CHROME to a Chrome or Chromium binary")
  for (const f of ["SingletonLock", "SingletonSocket", "SingletonCookie"]) fs.rmSync(path.join(profileFor(port), f), { force: true })
  const cdpPort = await freePort()
  const logFile = path.join(dirFor(port), "chrome.log")
  const log = fs.openSync(logFile, "a")
  const chrome = spawn(CHROME, ["--headless=new", `--remote-debugging-port=${cdpPort}`, chromeNeedle(port), "--no-first-run", "--no-default-browser-check", "about:blank"], { detached: true, stdio: ["ignore", log, log] })
  chrome.unref()
  for (let i = 0; i < 150; i++) {
    if (!alive(chrome.pid)) die(`Chrome exited during startup\n${tail(logFile)}`)
    try { await fetch(`http://127.0.0.1:${cdpPort}/json/version`); return { ...s, chromePid: chrome.pid, cdpPort } } catch { await sleep(100) }
  }
  die(`Chrome did not open its DevTools port within 15s; see ${logFile}`)
}

const holderNeedle = (port) => `mp.mjs hold --port ${port}`
const holderUp = (s, port) => !!s && ours(s.holderPid, holderNeedle(port))

async function hold(flags) {
  const port = Number(flags.port)
  let session, applied, appliedZone
  for (;;) {
    const s = readState(port)
    if (!s && !fs.existsSync(path.join(dirFor(port), "state.json"))) return
    if (!s) { await sleep(150); continue }
    if (!chromeUp(s, port)) return
    try {
      if (session) await session.evaluate("1")
    } catch { session = null; applied = null; appliedZone = null }
    try {
      if (!session) {
        session = await cdpSession(port)
        const opened = session
        opened.on("Page.javascriptDialogOpening", ({ type, message }) => {
          fs.appendFileSync(path.join(dirFor(port), "dialogs.log"), `${new Date().toISOString()} ${type} accepted: ${message}\n`)
          opened.send("Page.handleJavaScriptDialog", { accept: true }).catch(() => {})
        })
      }
      const want = JSON.stringify(s.viewport)
      if (applied !== want) {
        await session.send("Emulation.setDeviceMetricsOverride", { width: s.viewport.width, height: s.viewport.height, deviceScaleFactor: 1, mobile: s.viewport.width < 500 })
        applied = want
      }
      const zone = s.timezone ?? ""
      if (appliedZone !== zone) {
        await session.send("Emulation.setTimezoneOverride", { timezoneId: zone })
        appliedZone = zone
      }
    } catch (e) { console.error(e.message); session = null }
    await sleep(150)
  }
}

async function startHolder(port, s) {
  const log = fs.openSync(path.join(dirFor(port), "holder.log"), "a")
  const holder = spawn(process.execPath, [fileURLToPath(import.meta.url), "hold", "--port", String(port)], { detached: true, stdio: ["ignore", log, log] })
  holder.unref()
  return { ...s, holderPid: holder.pid }
}

async function boot(flags) {
  return withLock(async () => {
    const live = liveInstances()
    if (!flags.port && live.length > 1) die(`several instances running (${live.join(", ")}); pass --port N`)
    const port = flags.port ? Number(flags.port) : live.length === 1 ? live[0] : await (async () => { for (let p = 3100; ; p++) if (await portFree(p)) return p })()
    let s = readState(port) ?? { viewport: { width: 1280, height: 800 } }
    fs.mkdirSync(dirFor(port), { recursive: true })
    if (!serverUp(s, port)) {
      if (!(await portFree(port))) die(`port ${port} is in use by a process this skill did not start`)
      s = await startServer(port, s)
      writeState(port, s)
    }
    if (!chromeUp(s, port)) {
      s = await startChrome(port, s)
      writeState(port, s)
    }
    if (!holderUp(s, port)) {
      s = await startHolder(port, s)
      writeState(port, s)
    }
    await waitUp(port, s)
    const b = await cdpSession(port)
    for (let i = 0; i < 50 && (await b.evaluate("innerWidth")) !== s.viewport.width; i++) await sleep(100)
    await signIn(b, port, "demo", demoPassword())
    const url = await b.evaluate("location.href")
    b.close()
    if (new URL(url).pathname.startsWith("/session")) die(`sign-in failed, ended at ${url}`)
    console.log(`${url} port=${port} user=demo`)
  })
}

async function stop(flags) {
  const port = resolvePort(flags)
  const s = readState(port)
  if (!s) return console.log(`nothing recorded for ${port}`)
  if (recorderUp(s, port)) await recordStop(port)
  const targets = [[s.holderPid, holderNeedle(port)], [s.chromePid, chromeNeedle(port)], [s.serverPid, serverNeedles(port)]].filter(([pid, needles]) => ours(pid, ...[needles].flat()))
  const allGone = () => targets.every(([pid]) => !alive(pid))
  for (const [pid] of targets) process.kill(pid, "SIGTERM")
  for (let i = 0; i < 80 && !allGone(); i++) await sleep(100)
  if (!allGone()) {
    for (const [pid] of targets) if (alive(pid)) process.kill(pid, "SIGKILL")
    for (let i = 0; i < 30 && !allGone(); i++) await sleep(100)
  }
  if (!allGone()) die(`pids ${targets.filter(([pid]) => alive(pid)).map(([pid]) => pid)} survived SIGKILL; state kept in ${dirFor(port)}`)
  await sleep(300)
  fs.rmSync(dirFor(port), { recursive: true, force: true, maxRetries: 5, retryDelay: 200 })
  console.log(`stopped ${port}`)
}

async function doctor(flags) {
  const port = resolvePort(flags)
  const s = readState(port)
  const out = { port, serverAlive: serverUp(s, port), chromeAlive: chromeUp(s, port) }
  try { out.up = (await fetch(`http://127.0.0.1:${port}/up`)).status } catch { out.up = null }
  if (out.chromeAlive) {
    const b = await cdpSession(port)
    out.url = await b.evaluate("location.href")
    out.theme = await b.evaluate("document.documentElement.dataset.theme")
    out.viewport = s.viewport
    out.inner = await b.evaluate("[innerWidth, innerHeight]")
    b.close()
  }
  out.holderAlive = holderUp(s, port)
  out.timezone = s?.timezone ?? null
  out.recording = recorderUp(s, port) ? s.recording.file : null
  console.log(JSON.stringify(out))
  const innerMatches = out.inner && out.inner[0] === s.viewport.width && out.inner[1] === s.viewport.height
  if (!out.serverAlive || out.up !== 200 || !out.chromeAlive || !out.holderAlive || !innerMatches) process.exit(1)
}

async function server(flags, action) {
  const port = resolvePort(flags)
  let s = readState(port) ?? die(`nothing recorded for ${port}; run: mp.mjs boot --port ${port}`)
  if (action === "stop") {
    if (!serverUp(s, port)) return console.log(`server on ${port} already down`)
    process.kill(s.serverPid, "SIGTERM")
    for (let i = 0; i < 80 && alive(s.serverPid); i++) await sleep(100)
    if (alive(s.serverPid)) process.kill(s.serverPid, "SIGKILL")
    for (let i = 0; i < 30 && !(await portFree(port)); i++) await sleep(100)
    return console.log(`server on ${port} down`)
  }
  if (action !== "start") die("server takes stop or start")
  await withLock(async () => {
    if (!serverUp(s, port)) {
      if (!(await portFree(port))) die(`port ${port} is in use by a process this skill did not start`)
      s = await startServer(port, readState(port))
      writeState(port, s)
    }
    await waitUp(port, s)
  })
  console.log(`server on ${port} up`)
}

async function zone(flags, name) {
  const port = resolvePort(flags)
  if (!name) die("zone takes an IANA name such as Pacific/Kiritimati, or off")
  const s = readState(port)
  if (name === "off") delete s.timezone
  else s.timezone = name
  writeState(port, s)
  const b = await cdpSession(port)
  const resolved = "Intl.DateTimeFormat().resolvedOptions().timeZone"
  const want = name === "off" ? Intl.DateTimeFormat().resolvedOptions().timeZone : name
  let now
  for (let i = 0; i < 50 && (now = await b.evaluate(resolved)) !== want; i++) await sleep(100)
  b.close()
  if (now !== want) die(`browser zone is ${now}, not ${want}; see ${dirFor(port)}/holder.log`)
  console.log(`${now} (reload with goto so the page reads it on load)`)
}

const recorderNeedle = (port) => `mp.mjs recorder --port ${port}`
const recorderUp = (s, port) => !!s?.recording && ours(s.recording.pid, recorderNeedle(port))

async function recorder(flags) {
  const port = Number(flags.port)
  const frames = path.join(dirFor(port), "frames")
  fs.mkdirSync(frames, { recursive: true })
  const b = await cdpSession(port)
  const index = []
  b.on("Page.screencastFrame", ({ data, metadata, sessionId }) => {
    const file = path.join(frames, `${String(index.length).padStart(6, "0")}.jpg`)
    fs.writeFileSync(file, Buffer.from(data, "base64"))
    index.push({ file, at: metadata.timestamp })
    b.send("Page.screencastFrameAck", { sessionId }).catch(() => {})
  })
  const { viewport } = readState(port)
  await b.send("Page.startScreencast", { format: "jpeg", quality: 85, maxWidth: viewport.width, maxHeight: viewport.height, everyNthFrame: 1 })
  const finish = () => {
    fs.writeFileSync(path.join(frames, "index.json"), JSON.stringify({ frames: index, end: Date.now() / 1000 }))
    process.exit(0)
  }
  process.on("SIGTERM", finish)
  setInterval(() => {}, 1 << 30)
}

async function recordStart(port, file) {
  if (!file?.endsWith(".mp4")) die("record start takes an output path ending in .mp4")
  if (!onPath("ffmpeg")) die("record needs ffmpeg on PATH")
  const s = readState(port)
  if (recorderUp(s, port)) die(`already recording to ${s.recording.file}; run: mp.mjs record stop`)
  fs.rmSync(path.join(dirFor(port), "frames"), { recursive: true, force: true })
  const log = fs.openSync(path.join(dirFor(port), "recorder.log"), "a")
  const child = spawn(process.execPath, [fileURLToPath(import.meta.url), "recorder", "--port", String(port)], { detached: true, stdio: ["ignore", log, log] })
  child.unref()
  writeState(port, { ...s, recording: { pid: child.pid, file: path.resolve(file) } })
  for (let i = 0; i < 50 && !fs.existsSync(path.join(dirFor(port), "frames", "000000.jpg")); i++) await sleep(100)
  if (!fs.existsSync(path.join(dirFor(port), "frames", "000000.jpg"))) die(`recorder sent no frame within 5s; see ${dirFor(port)}/recorder.log`)
  console.log(`recording to ${path.resolve(file)}`)
}

async function recordStop(port) {
  const s = readState(port)
  if (!recorderUp(s, port)) die(`not recording on ${port}`)
  process.kill(s.recording.pid, "SIGTERM")
  for (let i = 0; i < 50 && alive(s.recording.pid); i++) await sleep(100)
  const frames = path.join(dirFor(port), "frames")
  const { frames: list, end } = JSON.parse(fs.readFileSync(path.join(frames, "index.json"), "utf8"))
  const lines = list.flatMap((f, i) => [`file '${f.file}'`, `duration ${((list[i + 1]?.at ?? end) - f.at).toFixed(3)}`])
  lines.push(`file '${list.at(-1).file}'`)
  fs.writeFileSync(path.join(frames, "concat.txt"), lines.join("\n"))
  fs.mkdirSync(path.dirname(s.recording.file), { recursive: true })
  const r = spawnSync("ffmpeg", ["-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", path.join(frames, "concat.txt"), "-fps_mode", "cfr", "-r", "30", "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", "-pix_fmt", "yuv420p", s.recording.file], { encoding: "utf8" })
  if (r.status !== 0) die(`ffmpeg failed; frames kept in ${frames}\n${r.stderr}`)
  fs.rmSync(frames, { recursive: true, force: true })
  const { recording } = s
  delete s.recording
  writeState(port, s)
  console.log(`${recording.file} ${(end - list[0].at).toFixed(1)}s ${list.length} frames`)
}

const percentile = (sorted, p) => sorted[Math.min(sorted.length - 1, Math.ceil((p / 100) * sorted.length) - 1)]

function latencyReport(file) {
  const samples = fs.readFileSync(file, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l))
  const ms = samples.map((x) => x.ms).filter((x) => x !== null).sort((a, b) => a - b)
  const round = (x) => x === undefined ? null : Math.round(x * 10) / 10
  console.log(JSON.stringify({ n: samples.length, timeouts: samples.length - ms.length, p50: round(percentile(ms, 50)), p95: round(percentile(ms, 95)), max: round(ms.at(-1)) }))
}

const LATENCY_PROBE = (end, timeout) => `window.__mpLatency = new Promise((resolve) => {
  addEventListener("keydown", (e) => {
    const painted = () => setTimeout(() => requestAnimationFrame(() => setTimeout(() => resolve(performance.now() - e.timeStamp))))
    if (${JSON.stringify(end)} === "paint") painted()
    else document.addEventListener(${JSON.stringify(end)}, painted, { capture: true, once: true })
  }, { capture: true, once: true })
  setTimeout(() => resolve(null), ${timeout})
}); true`

const QUIET_PROBE = (end, ms) => `new Promise((resolve) => {
  let last = performance.now()
  const seen = () => { last = performance.now() }
  document.addEventListener(${JSON.stringify(end)}, seen, true)
  const check = () => {
    if (performance.now() - last < ${ms}) return setTimeout(check, 25)
    document.removeEventListener(${JSON.stringify(end)}, seen, true)
    resolve(true)
  }
  check()
})`

async function latency(b, keyName, flags) {
  if (!flags.end) die("latency needs --end <event>, such as turbo:frame-render or turbo:morph, or --end paint")
  if (flags.end !== "paint") await b.evaluate(QUIET_PROBE(flags.end, 250))
  await b.evaluate(LATENCY_PROBE(flags.end, Number(flags.timeout ?? 5000)))
  await b.key(keyName)
  const ms = await b.evaluate("window.__mpLatency")
  const sample = { key: keyName, end: flags.end, ms: ms === null ? null : Math.round(ms * 10) / 10 }
  if (flags.log) fs.appendFileSync(flags.log, `${JSON.stringify(sample)}\n`)
  console.log(JSON.stringify(sample))
  if (ms === null) process.exitCode = 1
}

const WAIT_PROBE = (selector, text) => `(() => {
  const hit = [...document.querySelectorAll(${JSON.stringify(selector)})].find((e) => ${JSON.stringify(text ?? null)} === null || e.innerText.includes(${JSON.stringify(text ?? "")}))
  return hit ? hit.innerText.trim().replace(/\\s+/g, " ").slice(0, 300) || "(matched, no text)" : null
})()`

async function wait(b, selector, flags) {
  if (!selector) die("wait needs a selector")
  const end = Date.now() + Number(flags.timeout ?? 5000)
  for (;;) {
    const hit = await b.evaluate(WAIT_PROBE(selector, flags.text)).catch(() => null)
    if (flags.gone ? hit === null : hit !== null) return console.log(flags.gone ? `gone ${selector}` : hit)
    if (Date.now() > end) die(`timed out: ${selector}${flags.text ? ` with text ${JSON.stringify(flags.text)}` : ""} ${flags.gone ? "still present" : "not found"}`)
    await sleep(50)
  }
}

const READONLY_RUNNER = `
  config = ActiveRecord::Base.connection_db_config.configuration_hash.merge(readonly: true)
  ActiveRecord::Base.establish_connection(config)
  puts eval(ENV.fetch("MP_QUERY")).inspect
`

const USAGE = `usage: mp.mjs <command> [--port N]
  boot [--port N]                    start server + headless Chrome, sign in as demo, print the Overview URL (idempotent)
  stop                               stop this instance and remove its state
  doctor                             print instance health as JSON, exit 1 if unhealthy
  goto <path>                        navigate, e.g. /session/new
  type <selector> <text> [--clear] [--delay ms]
                                     focus the element and type text key by key, --delay ms between keys
  key <Key> [<Key>...]               Enter, Escape, Tab, ArrowDown, Backspace, a, Meta+z, Shift+Tab; several keys go back to back
  wait <selector> [--text s] [--gone] [--timeout ms]
                                     poll until an element matches (and contains s), or until none does; prints its text
  click <selector>                   mouse click on the element's center
  shot <file.png> [--full]           screenshot the viewport, or the whole page with --full
  resize <w> <h>                     set the emulated viewport; the per-instance holder keeps it between commands
  theme light|dark                   click the sidebar theme button on the current page
  signin <user> <password>           sign in through the form
  signout                            DELETE /session and land on the sign-in page
  js <expr>                          evaluate JS in the page, print the JSON result
  text [selector]                    print visible text
  query <ruby>                       evaluate Ruby against a read-only SQLite connection
  server stop|start                  stop or start only the Rails server; the page and its field stay as they are
  zone <IANA>|off                    emulate the browser time zone; the holder keeps it between commands
  record start <file.mp4> | record stop
                                     screencast the page to an mp4 (needs ffmpeg); stop also finalizes it
  latency <Key> --end <event>|paint [--log file.jsonl] [--timeout ms]
                                     press Key and print ms from its keydown to the paint after <event> fires
  latency --report file.jsonl        print n, timeouts, p50, p95, max of logged samples`

async function main() {
  const { flags, rest } = parseArgs(process.argv.slice(2))
  const [cmd, ...args] = rest
  if (cmd === "boot") return boot(flags)
  if (cmd === "hold") return hold(flags)
  if (cmd === "stop") return stop(flags)
  if (cmd === "doctor") return doctor(flags)
  if (cmd === "recorder") return recorder(flags)
  if (cmd === "server") return server(flags, args[0])
  if (cmd === "zone") return zone(flags, args[0])
  if (cmd === "record") {
    const port = resolvePort(flags)
    if (args[0] === "start") return recordStart(port, args[1])
    if (args[0] === "stop") return recordStop(port)
    die("record takes start <file.mp4> or stop")
  }
  if (cmd === "latency" && flags.report) return latencyReport(flags.report)
  if (cmd === "query") {
    if (!args[0]) die("query needs a Ruby expression")
    return console.log(rails(["runner", READONLY_RUNNER], { MP_QUERY: args[0] }).trim())
  }
  if (!["goto", "type", "key", "click", "shot", "resize", "theme", "signin", "signout", "js", "text", "wait", "latency"].includes(cmd)) {
    console.error(USAGE)
    process.exit(cmd ? 1 : 0)
  }
  const port = resolvePort(flags)
  const b = await cdpSession(port)
  const origin = `http://localhost:${port}`
  try {
    if (cmd === "goto") {
      await b.goto(new URL(args[0], origin).href)
      console.log(await b.evaluate("location.href"))
    } else if (cmd === "type") {
      if (!(await b.focus(args[0]))) die(`no element matches ${args[0]}`)
      if (flags.clear) {
        await b.evaluate("document.activeElement.select()")
        await b.key("Backspace")
      }
      for (const ch of args[1]) {
        await b.typeChar(ch)
        if (flags.delay) await sleep(Number(flags.delay))
      }
      console.log(JSON.stringify(await b.evaluate("document.activeElement.value")))
    } else if (cmd === "key") {
      if (!args.length) die("key needs at least one key")
      for (const k of args) await b.key(k)
      await sleep(200)
      console.log(`pressed ${args.join(" ")}`)
    } else if (cmd === "click") {
      await b.click(args[0])
      await b.settle()
      console.log(await b.evaluate("location.href"))
    } else if (cmd === "shot") {
      const params = { format: "png" }
      if (flags.full) {
        const { cssContentSize: size } = await b.send("Page.getLayoutMetrics")
        Object.assign(params, { captureBeyondViewport: true, clip: { x: 0, y: 0, width: Math.ceil(size.width), height: Math.ceil(size.height), scale: 1 } })
      }
      const { data } = await b.send("Page.captureScreenshot", params)
      fs.mkdirSync(path.dirname(path.resolve(args[0])), { recursive: true })
      fs.writeFileSync(args[0], Buffer.from(data, "base64"))
      console.log(path.resolve(args[0]))
    } else if (cmd === "resize") {
      const s = readState(port)
      s.viewport = { width: Number(args[0]), height: Number(args[1]) }
      writeState(port, s)
      const dims = () => b.evaluate("[innerWidth, innerHeight]")
      for (let i = 0; i < 50 && (await dims()).join("x") !== `${s.viewport.width}x${s.viewport.height}`; i++) await sleep(100)
      const [w, h] = await dims()
      if (w !== s.viewport.width || h !== s.viewport.height) die(`viewport holder did not apply ${s.viewport.width}x${s.viewport.height}; see ${dirFor(port)}/holder.log`)
      console.log(`${w}x${h} scrollWidth=${await b.evaluate("document.documentElement.scrollWidth")}`)
    } else if (cmd === "theme") {
      if (!["light", "dark"].includes(args[0])) die("theme takes light or dark")
      await b.click(`button[data-theme="${args[0]}"]`)
      const applied = `document.documentElement.dataset.theme === "${args[0]}" && document.cookie.includes("theme=${args[0]}")`
      for (let i = 0; i < 50 && !(await b.evaluate(applied).catch(() => false)); i++) await sleep(100)
      if (!(await b.evaluate(applied))) die(`theme did not become ${args[0]} (data-theme and theme cookie) within 5s`)
      await b.settle()
      console.log(args[0])
    } else if (cmd === "signin") {
      await signIn(b, port, args[0], args[1])
      console.log(await b.evaluate("location.href"))
    } else if (cmd === "signout") {
      await b.goto(`${origin}/session/new`)
      await b.evaluate(`fetch("/session", { method: "DELETE", headers: { "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content } })`)
      await b.goto(`${origin}/session/new`)
      console.log(await b.evaluate("location.href"))
    } else if (cmd === "js") {
      console.log(JSON.stringify(await b.evaluate(args[0])))
    } else if (cmd === "text") {
      console.log(await b.evaluate(`document.querySelector(${JSON.stringify(args[0] || "body")}).innerText`))
    } else if (cmd === "wait") {
      await wait(b, args[0], flags)
    } else if (cmd === "latency") {
      await latency(b, args[0], flags)
    }
  } finally {
    b.close()
  }
}
main().catch((e) => die(e.message))
