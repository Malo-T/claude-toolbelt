// The gauge's text, null until the first refresh.
export type GaugeLine = string | null

declare module 'claude-code' {
  interface PluginState {
    'context-gauge': {
      line: GaugeLine
    }
  }
}
