const API_URL = (import.meta.env.VITE_API_URL || 'http://127.0.0.1:8080').replace(/\/$/, '')

export type FilterParams = { genres: string[]; artistIds: string[]; albumIds: string[] }
export type PickerItem = { id: string; name: string; subtitle: string }
export type Track = { trackUri: string; playHistoryId: string }

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const response = await fetch(`${API_URL}${path}`, {
    ...init, credentials: 'include',
    headers: { Accept: 'application/json', ...(init.body ? { 'Content-Type': 'application/json' } : {}), ...init.headers },
  })
  if (response.status === 204) return undefined as T
  const text = await response.text()
  const body = text ? JSON.parse(text) : undefined
  if (!response.ok) throw new Error(body?.message || `Request failed (${response.status})`)
  return body as T
}

export const api = {
  health: () => request<unknown>('/health'),
  session: () => request<{ valid: boolean; user: { id: string; displayName: string } }>('/auth/session'),
  logout: () => request<void>('/auth/logout', { method: 'POST' }),
  exchangeSpotifyCode: (body: { code: string; redirectUri: string; codeVerifier: string }) =>
    request<{ expiresAt: string }>('/auth/spotify/callback', { method: 'POST', body: JSON.stringify(body) }),
  playbackToken: () => request<{ accessToken: string }>('/auth/spotify/playback-token'),
  genres: () => request<{ genres: string[] }>('/radio/genres'),
  search: (query: string, type: 'artist' | 'album') =>
    request<{ items: PickerItem[] }>(`/radio/search?q=${encodeURIComponent(query)}&type=${type}`),
  startRadio: (filters: FilterParams) => request<{ radioSessionId: string }>('/radio/start', { method: 'POST', body: JSON.stringify(filters) }),
  restartRadio: (sessionId: string, filters: FilterParams) => request<{ radioSessionId: string }>(`/radio/${encodeURIComponent(sessionId)}/restart`, { method: 'POST', body: JSON.stringify(filters) }),
  nextTrack: (sessionId: string) => request<Track>(`/radio/${encodeURIComponent(sessionId)}/next-track`),
  markPlayed: (sessionId: string, playHistoryId: string) => request<void>(`/radio/${encodeURIComponent(sessionId)}/mark-played`, {
    method: 'POST', body: JSON.stringify({ playHistoryId, playedAt: new Date().toISOString() }),
  }),
  endRadio: (sessionId: string) => request<void>(`/radio/${encodeURIComponent(sessionId)}/end`, { method: 'POST' }),
}
