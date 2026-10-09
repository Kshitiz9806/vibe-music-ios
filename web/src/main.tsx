import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react'
import { createRoot } from 'react-dom/client'
import { api, type FilterParams, type PickerItem, type Track } from './api'
import './styles.css'

type SpotifyState = { paused: boolean; position: number; duration: number; track_window: { current_track: { uri: string } } }
type SpotifyPlayer = {
  connect(): Promise<boolean>; disconnect(): void; pause(): Promise<void>; resume(): Promise<void>; activateElement(): Promise<void>
  addListener(event: string, callback: (data: any) => void): boolean
}
declare global {
  interface Window {
    Spotify?: { Player: new (options: { name: string; volume: number; enableMediaSession: false; getOAuthToken: (callback: (token: string) => void) => void }) => SpotifyPlayer }
    onSpotifyWebPlaybackSDKReady?: () => void
  }
  interface ImportMeta { env: { VITE_API_URL?: string; VITE_SPOTIFY_CLIENT_ID?: string; VITE_SPOTIFY_REDIRECT_URI?: string } }
}

const CLIENT_ID = import.meta.env.VITE_SPOTIFY_CLIENT_ID || ''
const CALLBACK_URI = import.meta.env.VITE_SPOTIFY_REDIRECT_URI || `${window.location.origin}/auth/callback`
let sdkLoad: Promise<void> | undefined

function loadSpotifySdk() {
  if (window.Spotify) return Promise.resolve()
  if (sdkLoad) return sdkLoad
  sdkLoad = new Promise<void>((resolve, reject) => {
    const timeout = window.setTimeout(() => reject(new Error('Spotify player took too long to load.')), 15000)
    window.onSpotifyWebPlaybackSDKReady = () => { window.clearTimeout(timeout); resolve() }
    const script = document.createElement('script')
    script.src = 'https://sdk.scdn.co/spotify-player.js'
    script.async = true
    script.onerror = () => { window.clearTimeout(timeout); reject(new Error('Could not load the Spotify player.')) }
    document.body.append(script)
  })
  return sdkLoad
}

function base64Url(bytes: Uint8Array) {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

async function beginSpotifyLogin() {
  if (!CLIENT_ID) throw new Error('Set VITE_SPOTIFY_CLIENT_ID in web/.env.local first.')
  const random = crypto.getRandomValues(new Uint8Array(64))
  const verifier = base64Url(random)
  const state = base64Url(crypto.getRandomValues(new Uint8Array(32)))
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(verifier))
  const challenge = base64Url(new Uint8Array(digest))
  sessionStorage.setItem('spotify_code_verifier', verifier)
  sessionStorage.setItem('spotify_oauth_state', state)
  sessionStorage.setItem('spotify_redirect_uri', CALLBACK_URI)
  const params = new URLSearchParams({
    client_id: CLIENT_ID,
    response_type: 'code',
    redirect_uri: CALLBACK_URI,
    state,
    scope: 'user-read-email user-read-private user-top-read user-library-read streaming user-modify-playback-state',
    code_challenge_method: 'S256',
    code_challenge: challenge,
  })
  window.location.assign(`https://accounts.spotify.com/authorize?${params}`)
}

async function finishSpotifyLogin() {
  const query = new URLSearchParams(window.location.search)
  const code = query.get('code')
  const error = query.get('error')
  if (error) throw new Error(`Spotify authorization failed: ${error}`)
  if (!code) throw new Error('Spotify did not return an authorization code.')
  const state = sessionStorage.getItem('spotify_oauth_state')
  const verifier = sessionStorage.getItem('spotify_code_verifier')
  const redirectUri = sessionStorage.getItem('spotify_redirect_uri')
  if (!state || state !== query.get('state') || !verifier || !redirectUri) throw new Error('Spotify sign-in could not be verified. Please try again.')
  await api.exchangeSpotifyCode({ code, redirectUri, codeVerifier: verifier })
  sessionStorage.removeItem('spotify_oauth_state')
  sessionStorage.removeItem('spotify_code_verifier')
  sessionStorage.removeItem('spotify_redirect_uri')
  window.history.replaceState({}, document.title, '/')
}

async function spotifyAccessToken() {
  return (await api.playbackToken()).accessToken
}

function Icon({ name, size = 18 }: { name: string; size?: number }) {
  const common = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: 'currentColor', strokeWidth: 2, strokeLinecap: 'round' as const, strokeLinejoin: 'round' as const, 'aria-hidden': true as const }
  const paths: Record<string, ReactNode> = {
    search: <><circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/></>,
    plus: <><path d="M12 5v14M5 12h14"/></>,
    check: <path d="m5 12 4 4L19 6"/>,
    close: <><path d="m18 6-12 12M6 6l12 12"/></>,
    play: <path d="m8 5 12 7-12 7z" fill="currentColor" stroke="none"/>,
    pause: <><path d="M8 5v14M16 5v14" strokeWidth="3"/></>,
    restart: <><path d="M3 12a9 9 0 1 0 2.6-6.4L3 8"/><path d="M3 3v5h5"/></>,
    stop: <rect x="5" y="5" width="14" height="14" rx="2" fill="currentColor" stroke="none"/>,
    arrow: <><path d="M5 12h14"/><path d="m12 5 7 7-7 7"/></>,
    wave: <><path d="M2 12h3l2-8 4 16 3-12 2 8 2-4h4"/></>,
    logout: <><path d="M10 17l5-5-5-5M15 12H3"/><path d="M12 3h6a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-6"/></>,
    album: <><rect x="3" y="3" width="18" height="18" rx="3"/><circle cx="12" cy="12" r="4"/></>,
    artist: <><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/></>,
  }
  return <svg {...common}>{paths[name] || paths.wave}</svg>
}

function Brand({ compact = false }: { compact?: boolean }) {
  return <div className={`brand ${compact ? 'brand-compact' : ''}`}><img src="/assets/vibemusic-logo.png" alt="" /><span>VIBEMUSIC</span></div>
}

function App() {
  const [checking, setChecking] = useState(true)
  const [healthMessage, setHealthMessage] = useState('Waking up your radio…')
  const [user, setUser] = useState<{ id: string; displayName: string } | null>(null)
  const [loginError, setLoginError] = useState('')
  const [loginBusy, setLoginBusy] = useState(false)
  const [checkingSession, setCheckingSession] = useState(false)
  const [searchType, setSearchType] = useState<'artist' | 'album'>('artist')
  const [searchText, setSearchText] = useState('')
  const [searching, setSearching] = useState(false)
  const [searchResults, setSearchResults] = useState<PickerItem[]>([])
  const [genres, setGenres] = useState<string[]>([])
  const [selectedGenres, setSelectedGenres] = useState<string[]>([])
  const [selectedArtists, setSelectedArtists] = useState<PickerItem[]>([])
  const [selectedAlbums, setSelectedAlbums] = useState<PickerItem[]>([])
  const [genreLoading, setGenreLoading] = useState(false)
  const [filterError, setFilterError] = useState('')
  const [notice, setNotice] = useState('')
  const [sessionId, setSessionId] = useState<string | null>(null)
  const [loadingRadio, setLoadingRadio] = useState(false)
  const [isPlaying, setIsPlaying] = useState(false)
  const [playerError, setPlayerError] = useState('')
  const [profileMenu, setProfileMenu] = useState(false)
  const [sdkReady, setSdkReady] = useState(false)
  const playerRef = useRef<SpotifyPlayer | null>(null)
  const deviceRef = useRef('')
  const sessionRef = useRef<string | null>(null)
  const reservationRef = useRef(new Map<string, string>())
  const onPlayerStateRef = useRef<(state: SpotifyState | null) => void>(() => {})
  const nextTrackRef = useRef<() => Promise<void>>(async () => {})
  const previouslyPlayingRef = useRef(false)
  const userPausedRef = useRef(true)
  const lastUriRef = useRef('')
  const readyResolvers = useRef<Array<(deviceId: string) => void>>([])
  const accessTokenRef = useRef<{ value: string; expiresAt: number } | null>(null)
  const selectedCount = selectedGenres.length + selectedArtists.length + selectedAlbums.length
  const filters: FilterParams = {
    genres: selectedGenres,
    artistIds: selectedArtists.map(item => item.id),
    albumIds: selectedAlbums.map(item => item.id),
  }

  const getAccessToken = useCallback(async () => {
    const cached = accessTokenRef.current
    if (cached && cached.expiresAt > Date.now() + 60_000) return cached.value
    const value = await spotifyAccessToken()
    accessTokenRef.current = { value, expiresAt: Date.now() + 55 * 60_000 }
    return value
  }, [])

  const loadUser = useCallback(async () => {
    setCheckingSession(true)
    try {
      const result = await api.session()
      setUser(result.valid ? result.user : null)
    } catch {
      setUser(null)
    } finally {
      setCheckingSession(false)
    }
  }, [])

  useEffect(() => {
    let active = true
    const prepare = async () => {
      const started = Date.now()
      while (active) {
        try { await api.health(); break }
        catch {
          if (Date.now() - started > 90_000) {
            if (active) { setHealthMessage('The backend is taking longer than expected.'); setLoginError('The backend has not become ready yet. Refresh this page to try again.'); setChecking(false) }
            return
          }
          if (active) setHealthMessage('Waking up your radio…')
          await new Promise(resolve => window.setTimeout(resolve, 2500))
        }
      }
      if (!active) return
      try {
        if (window.location.pathname === '/auth/callback') {
          await finishSpotifyLogin()
          setLoginError('')
        }
      } catch (error) { setLoginError(error instanceof Error ? error.message : 'Spotify sign-in failed.') }
      await loadUser()
      if (active) setChecking(false)
    }
    void prepare()
    return () => { active = false }
  }, [loadUser])

  useEffect(() => {
    if (!user) return
    let live = true
    setGenreLoading(true)
    api.genres().then(result => { if (live) setGenres(result.genres) })
      .catch(error => { if (live) setFilterError(error.message) })
      .finally(() => { if (live) setGenreLoading(false) })
    return () => { live = false }
  }, [user])

  useEffect(() => {
    const query = searchText.trim()
    if (!user || !query) { setSearchResults([]); setSearching(false); return }
    let live = true
    setSearching(true)
    const timeout = window.setTimeout(() => {
      api.search(query, searchType).then(result => { if (live) setSearchResults(result.items) })
        .catch(error => { if (live) setFilterError(error.message) })
        .finally(() => { if (live) setSearching(false) })
    }, 350)
    return () => { live = false; window.clearTimeout(timeout) }
  }, [searchText, searchType, user])

  useEffect(() => {
    if (!notice) return
    const timer = window.setTimeout(() => setNotice(''), 1700)
    return () => window.clearTimeout(timer)
  }, [notice])

  useEffect(() => {
    if (!sessionId) return
    const keepWarm = window.setInterval(() => { void api.health().catch(() => {}) }, 10 * 60_000)
    return () => window.clearInterval(keepWarm)
  }, [sessionId])

  const markStarted = useCallback(async (uri: string) => {
    const historyId = reservationRef.current.get(uri)
    const id = sessionRef.current
    if (!historyId || !id) return
    reservationRef.current.delete(uri)
    try { await api.markPlayed(id, historyId) } catch (error) { setPlayerError(error instanceof Error ? error.message : 'Could not update playback history.') }
  }, [])

  const playNext = useCallback(async () => {
    const id = sessionRef.current
    if (!id || !deviceRef.current || !playerRef.current) return
    try {
      const track: Track = await api.nextTrack(id)
      if (!track?.trackUri) throw new Error('No tracks are available. Widen your selections and try again.')
      reservationRef.current.set(track.trackUri, track.playHistoryId)
      const accessToken = await getAccessToken()
      const url = `https://api.spotify.com/v1/me/player/play?device_id=${encodeURIComponent(deviceRef.current)}`
      const response = await fetch(url, { method: 'PUT', headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ uris: [track.trackUri] }) })
      if (!response.ok) throw new Error(response.status === 403 ? 'Spotify could not start playback. Check that this account has Premium and that browser playback is allowed.' : `Spotify playback failed (${response.status}).`)
    } catch (error) { setPlayerError(error instanceof Error ? error.message : 'Could not load the next track.') }
  }, [getAccessToken])
  nextTrackRef.current = playNext

  onPlayerStateRef.current = state => {
    if (!state) { setIsPlaying(false); previouslyPlayingRef.current = false; return }
    const uri = state.track_window.current_track.uri
    if (uri && uri !== lastUriRef.current) { lastUriRef.current = uri; void markStarted(uri) }
    const ended = previouslyPlayingRef.current && !userPausedRef.current && state.paused && state.duration > 0 && state.duration - state.position < 1500
    if (ended && sessionRef.current) void nextTrackRef.current()
    previouslyPlayingRef.current = !state.paused
    setIsPlaying(!state.paused)
  }

  const connectPlayer = useCallback(async () => {
    await loadSpotifySdk()
    const spotifySdk = window.Spotify
    if (!spotifySdk) throw new Error('Spotify’s browser player is unavailable in this browser.')
    if (!playerRef.current) {
      const player = new spotifySdk.Player({ name: 'VibeMusic Radio', volume: 0.8, enableMediaSession: false, getOAuthToken: callback => { void getAccessToken().then(callback).catch(error => setPlayerError(error.message)) } })
      player.addListener('ready', ({ device_id }: { device_id: string }) => {
        deviceRef.current = device_id
        setSdkReady(true)
        readyResolvers.current.splice(0).forEach(resolve => resolve(device_id))
      })
      player.addListener('not_ready', () => { deviceRef.current = ''; setSdkReady(false) })
      player.addListener('player_state_changed', (state: SpotifyState | null) => onPlayerStateRef.current(state))
      player.addListener('initialization_error', ({ message }: { message: string }) => setPlayerError(message))
      player.addListener('authentication_error', ({ message }: { message: string }) => setPlayerError(message))
      player.addListener('account_error', () => setPlayerError('Spotify browser playback requires a Premium account.'))
      player.addListener('playback_error', ({ message }: { message: string }) => setPlayerError(message))
      playerRef.current = player
      await player.connect()
    }
    await playerRef.current.activateElement()
    if (deviceRef.current) return deviceRef.current
    return await new Promise<string>((resolve, reject) => {
      const timeout = window.setTimeout(() => reject(new Error('Spotify player did not become ready. Please check that Spotify is available in this browser.')), 20_000)
      readyResolvers.current.push(deviceId => { window.clearTimeout(timeout); resolve(deviceId) })
    })
  }, [getAccessToken])

  const startPlayback = useCallback(async (params: FilterParams) => {
    setLoadingRadio(true)
    setPlayerError('')
    try {
      await connectPlayer()
      const radio = await api.startRadio(params)
      sessionRef.current = radio.radioSessionId
      setSessionId(radio.radioSessionId)
      const track = await api.nextTrack(radio.radioSessionId)
      if (!track?.trackUri) throw new Error('No tracks are available. Widen your selections and try again.')
      reservationRef.current.set(track.trackUri, track.playHistoryId)
      const accessToken = await getAccessToken()
      userPausedRef.current = false
      const response = await fetch(`https://api.spotify.com/v1/me/player/play?device_id=${encodeURIComponent(deviceRef.current)}`, {
        method: 'PUT', headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ uris: [track.trackUri] }),
      })
      if (!response.ok) throw new Error(response.status === 403 ? 'Spotify could not start playback. Check Premium access and browser playback permissions.' : `Spotify playback failed (${response.status}).`)
      setPlayerError('')
    } catch (error) {
      setPlayerError(error instanceof Error ? error.message : 'Could not start radio.')
      const id = sessionRef.current
      if (id) { try { await api.endRadio(id) } catch { /* keep the original player error */ } }
      sessionRef.current = null
      setSessionId(null)
      playerRef.current?.disconnect()
      playerRef.current = null
      deviceRef.current = ''
      setSdkReady(false)
    } finally { setLoadingRadio(false) }
  }, [connectPlayer, getAccessToken])

  const stopPlayback = useCallback(async (clearFilters: boolean) => {
    setLoadingRadio(true)
    const id = sessionRef.current
    userPausedRef.current = true
    try { await playerRef.current?.pause() } catch { /* continue closing the radio session */ }
    playerRef.current?.disconnect()
    playerRef.current = null
    deviceRef.current = ''
    sessionRef.current = null
    setSessionId(null)
    setSdkReady(false)
    setIsPlaying(false)
    reservationRef.current.clear()
    if (id) { try { await api.endRadio(id) } catch (error) { setPlayerError(error instanceof Error ? error.message : 'Could not end radio.') } }
    if (clearFilters) {
      setSelectedGenres([]); setSelectedArtists([]); setSelectedAlbums([]); setSearchText(''); setSearchResults([])
    }
    setLoadingRadio(false)
  }, [])

  const restartPlayback = useCallback(async () => {
    const id = sessionRef.current
    if (!id || !playerRef.current) return
    setLoadingRadio(true)
    setPlayerError('')
    reservationRef.current.clear()
    try {
      userPausedRef.current = true
      await playerRef.current.pause()
      const radio = await api.restartRadio(id, filters)
      sessionRef.current = radio.radioSessionId
      setSessionId(radio.radioSessionId)
      userPausedRef.current = false
      await playNext()
    } catch (error) {
      setPlayerError(error instanceof Error ? error.message : 'Could not restart radio.')
      await stopPlayback(false)
    } finally { setLoadingRadio(false) }
  }, [filters, playNext, stopPlayback])

  const signOut = useCallback(async () => {
    if (sessionRef.current) await stopPlayback(true)
    try { await api.logout() } catch { /* local UI still signs out */ }
    accessTokenRef.current = null
    setUser(null); setGenres([]); setSelectedGenres([]); setSelectedArtists([]); setSelectedAlbums([])
  }, [stopPlayback])

  const addSelection = (item: PickerItem) => {
    if (selectedCount >= 5) return
    const selected = searchType === 'artist' ? selectedArtists : selectedAlbums
    if (selected.some(value => value.id === item.id)) return
    if (searchType === 'artist') setSelectedArtists(values => [...values, item])
    else setSelectedAlbums(values => [...values, item])
    setNotice(`${item.name} added`)
  }

  const toggleGenre = (genre: string) => {
    if (selectedGenres.includes(genre)) setSelectedGenres(values => values.filter(value => value !== genre))
    else if (selectedCount < 5) { setSelectedGenres(values => [...values, genre]); setNotice(`${genre} added`) }
  }

  const removeSelected = (kind: 'genre' | 'artist' | 'album', id: string) => {
    if (kind === 'genre') setSelectedGenres(values => values.filter(value => value !== id))
    if (kind === 'artist') setSelectedArtists(values => values.filter(value => value.id !== id))
    if (kind === 'album') setSelectedAlbums(values => values.filter(value => value.id !== id))
  }

  const togglePlayback = () => {
    if (!playerRef.current) return
    if (isPlaying) { userPausedRef.current = true; void playerRef.current.pause() }
    else { userPausedRef.current = false; void playerRef.current.resume() }
  }

  if (checking) return <main className="startup"><Brand /><div className="loader-mark"><span /><span /><span /><span /><span /></div><p>{healthMessage}</p><span className="muted small">Checking radio connection</span></main>

  if (!user) return <main className="login-page"><div className="login-card"><Brand /><div className="login-art"><div className="halo" /><img src="/assets/vibemusic-logo.png" alt="VibeMusic" /></div><p className="eyebrow">YOUR RADIO, YOUR DIRECTION</p><h1>Pick a feeling.<br /><em>Find the flow.</em></h1><p className="login-copy">Choose a few sounds you love. VibeMusic builds a radio around them and lets the music take over.</p>{loginError && <div className="error-banner">{loginError}</div>}<button className="primary-button login-button" disabled={loginBusy} onClick={() => { setLoginError(''); setLoginBusy(true); void beginSpotifyLogin().catch(error => { setLoginBusy(false); setLoginError(error.message) }) }}>{loginBusy ? 'Opening Spotify…' : 'Continue with Spotify'} {!loginBusy && <Icon name="arrow" />}</button><p className="login-foot">Connect Spotify once to get started. Your sign-in stays on this browser.</p></div></main>

  if (sessionId) return <main className="player-page"><header className="topbar"><Brand compact /><button className="profile-button" onClick={() => setProfileMenu(value => !value)}><span className="avatar">{user.displayName.slice(0, 1).toUpperCase()}</span><span>{user.displayName}</span><span className="chevron">⌄</span></button>{profileMenu && <div className="profile-menu"><button onClick={() => { setProfileMenu(false); void signOut() }}><Icon name="logout" /> Sign out</button></div>}</header><section className="now-playing"><div className="sound-orbit orbit-one" /><div className="sound-orbit orbit-two" /><div className={`player-logo ${isPlaying ? 'is-playing' : ''}`}><img src="/assets/vibemusic-logo.png" alt="VibeMusic logo" /></div><div className="radio-state"><span className={`status-dot ${isPlaying ? 'active' : ''}`} />{isPlaying ? 'VIBE RADIO IS PLAYING' : sdkReady ? 'VIBE RADIO IS PAUSED' : 'CONNECTING TO RADIO'}</div><h1>Your vibe is on.</h1><p className="muted">{isPlaying ? 'Let the music find its way.' : 'Take a breath. Resume when you’re ready.'}</p><div className="elapsed">PERSONAL RADIO SESSION</div><button className="play-button" aria-label={isPlaying ? 'Pause radio' : 'Play radio'} onClick={togglePlayback} disabled={loadingRadio}><Icon name={isPlaying ? 'pause' : 'play'} size={25} /></button>{playerError && <div className="player-error">{playerError}</div>}<div className="playback-actions"><button className="secondary-button" onClick={() => void restartPlayback()} disabled={loadingRadio}><Icon name="restart" />{loadingRadio ? 'Restarting…' : 'Restart Radio'}</button><button className="end-button" onClick={() => void stopPlayback(true)} disabled={loadingRadio}><Icon name="stop" />End Radio</button></div></section><footer className="player-footer"><Brand compact /><span>Let the radio take it from here.</span></footer></main>

  return <main className="app-shell"><header className="topbar"><Brand compact /><div className="topbar-right"><span className="welcome">A radio for {user.displayName}</span><button className="profile-button" onClick={() => setProfileMenu(value => !value)}><span className="avatar">{user.displayName.slice(0, 1).toUpperCase()}</span><span>{user.displayName}</span><span className="chevron">⌄</span></button>{profileMenu && <div className="profile-menu"><button onClick={() => { setProfileMenu(false); void signOut() }}><Icon name="logout" /> Sign out</button></div>}</div></header>
    <section className="selection-bar"><div className="selection-head"><div><span className="eyebrow">YOUR RADIO, YOUR RULES</span><h2>Set your direction</h2></div><span className={`count-badge ${selectedCount === 5 ? 'full' : ''}`}>{selectedCount} <i>/</i> 5</span></div><div className="selected-chips">{selectedCount === 0 ? <span className="muted">Choose up to five genres, artists, or albums. Your choices stay visible here.</span> : <>{selectedGenres.map(value => <SelectedChip key={`g-${value}`} title={value} remove={() => removeSelected('genre', value)} />)}{selectedArtists.map(value => <SelectedChip key={`a-${value.id}`} title={value.name} remove={() => removeSelected('artist', value.id)} />)}{selectedAlbums.map(value => <SelectedChip key={`l-${value.id}`} title={value.name} remove={() => removeSelected('album', value.id)} />)}</>}</div></section>
    <div className="content"><section className="filter-card"><div className="section-title"><span className="section-icon"><Icon name="wave" /></span><div><span className="eyebrow">01 / CHOOSE A VIBE</span><h2>Start with a genre</h2></div></div><div className="genre-list">{genreLoading ? <p className="muted">Loading genres…</p> : genres.length ? <div className="genre-scroller"><div className="genre-grid">{genres.map(genre => { const selected = selectedGenres.includes(genre); return <button key={genre} className={`genre-chip ${selected ? 'selected' : ''}`} onClick={() => toggleGenre(genre)} disabled={!selected && selectedCount >= 5}>{selected && <Icon name="check" size={15} />}{titleCase(genre)}</button> })}</div></div> : <button className="text-button" onClick={() => { setGenreLoading(true); setFilterError(''); api.genres().then(result => setGenres(result.genres)).catch(error => setFilterError(error.message)).finally(() => setGenreLoading(false)) }}>Genres unavailable. Tap to retry.</button>}</div>
      <div className="divider" /><div className="section-title find-title"><span className="section-icon"><Icon name="search" /></span><div><span className="eyebrow">02 / MAKE IT PERSONAL</span><h2>Find artists or albums</h2></div></div><div className="search-controls"><div className="segmented"><button className={searchType === 'artist' ? 'active' : ''} onClick={() => { setSearchType('artist'); setFilterError(''); setSearchResults([]) }}><Icon name="artist" size={16} />Artist</button><button className={searchType === 'album' ? 'active' : ''} onClick={() => { setSearchType('album'); setFilterError(''); setSearchResults([]) }}><Icon name="album" size={16} />Album</button></div><label className="search-box"><Icon name="search" size={18} /><input value={searchText} onChange={event => { setSearchText(event.target.value); setFilterError(''); setSearchResults([]) }} placeholder={searchType === 'artist' ? 'Search artists' : 'Search albums'} /><kbd>↵</kbd></label></div><div className="results" aria-live="polite">{searchText.trim() && searchResults.length === 0 ? <p className="muted result-hint">{searching ? 'Searching…' : 'No matches found.'}</p> : searchResults.map(item => { const selected = (searchType === 'artist' ? selectedArtists : selectedAlbums).some(value => value.id === item.id); return <button key={item.id} className="result-row" onClick={() => addSelection(item)} disabled={selected || selectedCount >= 5}><span className="result-symbol"><Icon name={searchType} /></span><span className="result-label"><strong>{item.name}</strong>{item.subtitle && <small>{item.subtitle}</small>}</span><span className={`add-button ${selected ? 'is-selected' : ''}`}><Icon name={selected ? 'check' : 'plus'} /></span></button> })}</div>{(filterError || playerError) && <p className="error-text">{filterError || playerError}</p>}<p className="empty-hint">No filters? We’ll use your top tracks and saved music to find a starting point.</p></section>
      <aside className="side-card"><div className="side-art"><img src="/assets/vibemusic-logo.png" alt="VibeMusic" /><span className="side-glow" /></div><span className="eyebrow">A LITTLE LESS CHOOSING</span><h3>Only the feeling.<br /><em>None of the fuss.</em></h3><p>One continuous radio, shaped by the sounds you choose. No track list, no skip button—just the next right song.</p><div className="side-points"><span><i>01</i> Pick up to five filters</span><span><i>02</i> Start your radio</span><span><i>03</i> Stay in the moment</span></div><div className="privacy-note"><span className="privacy-dot" /> Spotify stays connected privately</div></aside></div>
    <div className="start-dock"><div><strong>{selectedCount ? `${selectedCount} filter${selectedCount === 1 ? '' : 's'} selected` : 'Ready when you are'}</strong><span>{selectedCount ? 'A radio made around your picks.' : 'Start with your listening history.'}</span></div><button className="primary-button" onClick={() => void startPlayback(filters)} disabled={loadingRadio}>{loadingRadio ? <><span className="button-loader" />Connecting…</> : <>Start Vibe Radio <Icon name="arrow" /></>}</button></div>
    {notice && <div className="toast"><span><Icon name="check" size={15} /></span>{notice}</div>}
  </main>
}

function SelectedChip({ title, remove }: { title: string; remove: () => void }) {
  return <span className="selected-chip"><span>{title}</span><button aria-label={`Remove ${title}`} onClick={remove}><Icon name="close" size={13} /></button></span>
}

function titleCase(value: string) { return value.replace(/\b\w/g, letter => letter.toUpperCase()) }

createRoot(document.getElementById('root')!).render(<App />)
