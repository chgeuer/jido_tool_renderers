/**
 * XtermSession — Phoenix LiveView hook for xterm.js terminal rendering.
 *
 * Usage:
 *   1. Install xterm.js in your consuming app:
 *      npm install @xterm/xterm @xterm/addon-fit
 *
 *   2. Import and register the hook in your app.js:
 *      import { XtermSession } from "jido_tool_renderers/xterm_hook"
 *      // or copy this file into your assets/js/ directory
 *
 *      let liveSocket = new LiveSocket("/live", Socket, {
 *        hooks: { XtermSession }
 *      })
 *
 *   3. Use in HEEx templates:
 *      <div id="my-term" phx-hook="XtermSession" phx-update="ignore"
 *           data-initial="optional initial ANSI content"
 *           class="h-[400px]">
 *      </div>
 *
 * The hook listens for `xterm:write` push events from the server:
 *   push_event(socket, "xterm:write", %{data: ansi_string, target: "my-term"})
 *
 * And `xterm:clear` to reset the terminal:
 *   push_event(socket, "xterm:clear", %{target: "my-term"})
 */

// Dynamic import — consuming app must have @xterm/xterm installed
let xtermModule = null;
let fitAddonModule = null;

async function loadXterm() {
  if (!xtermModule) {
    xtermModule = await import("@xterm/xterm");
    try {
      fitAddonModule = await import("@xterm/addon-fit");
    } catch (_e) {
      // fit addon is optional
      console.warn("@xterm/addon-fit not available, terminal won't auto-resize");
    }
  }
  return { Terminal: xtermModule.Terminal, FitAddon: fitAddonModule?.FitAddon };
}

export const XtermSession = {
  async mounted() {
    const { Terminal, FitAddon } = await loadXterm();

    this.term = new Terminal({
      cursorBlink: false,
      disableStdin: true,
      convertEol: true,
      fontSize: 13,
      fontFamily: "'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace",
      theme: {
        background: "#1e1e1e",
        foreground: "#d4d4d4",
        cursor: "#d4d4d4",
        selectionBackground: "#264f78",
        black: "#1e1e1e",
        red: "#f44747",
        green: "#6a9955",
        yellow: "#dcdcaa",
        blue: "#569cd6",
        magenta: "#c586c0",
        cyan: "#4ec9b0",
        white: "#d4d4d4",
        brightBlack: "#808080",
        brightRed: "#f44747",
        brightGreen: "#6a9955",
        brightYellow: "#dcdcaa",
        brightBlue: "#569cd6",
        brightMagenta: "#c586c0",
        brightCyan: "#4ec9b0",
        brightWhite: "#ffffff",
      },
    });

    if (FitAddon) {
      this.fitAddon = new FitAddon();
      this.term.loadAddon(this.fitAddon);
    }

    this.term.open(this.el);

    if (this.fitAddon) {
      this.fitAddon.fit();
    }

    // Write initial content if provided
    const initial = this.el.dataset.initial;
    if (initial) {
      this.term.write(initial);
    }

    // Listen for server push events
    this.handleEvent("xterm:write", ({ data, target }) => {
      if (!target || target === this.el.id) {
        this.term.write(data);
      }
    });

    this.handleEvent("xterm:clear", ({ target }) => {
      if (!target || target === this.el.id) {
        this.term.clear();
      }
    });

    // Handle resize
    this._resizeObserver = new ResizeObserver(() => {
      if (this.fitAddon) {
        this.fitAddon.fit();
      }
    });
    this._resizeObserver.observe(this.el);
  },

  updated() {
    // phx-update="ignore" prevents this from firing, but just in case
    if (this.fitAddon) {
      this.fitAddon.fit();
    }
  },

  destroyed() {
    if (this._resizeObserver) {
      this._resizeObserver.disconnect();
    }
    if (this.term) {
      this.term.dispose();
    }
  },
};
