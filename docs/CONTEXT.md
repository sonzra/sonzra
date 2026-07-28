# Sonzra

> Open-source, self-hosted audio player for Jellyfin built with Ruby on Rails and Hotwire.

---

# Project Vision

Sonzra is a modern audio player for Jellyfin focused on:

- Music
- Podcasts
- Audiobooks

Unlike traditional desktop players, Sonzra is a Rails web application designed from the beginning to become a native mobile application using Hotwire Native.

The same Rails application should power:

- Web browsers
- Android
- iOS

There should be only one UI and one codebase.

The application should feel alive through Turbo Streams and WebSockets rather than heavy client-side JavaScript.

---

# Philosophy

The project should embrace Rails conventions.

Goals:

- Server-rendered HTML
- Turbo everywhere
- Stimulus only when needed
- Minimal JavaScript
- No React
- No Vue
- No SPA architecture

Everything should feel fast while remaining simple.

---

# Target Stack

## Backend

- Ruby 4.x (latest stable)
- Rails 8.x (latest stable)

Use:

- Action Cable
- Turbo Streams
- Solid Queue
- Solid Cache
- Solid Cable
- SQLite for development
- PostgreSQL optional for production

---

## Frontend

- Turbo
- Stimulus
- Importmaps (unless a compelling reason exists to switch)

No React.

No Vite unless absolutely necessary.

---

## Native

The application must be compatible with:

- Hotwire Native for iOS
- Hotwire Native for Android

https://native.hotwired.dev/

Avoid browser APIs that do not work inside Hotwire Native.

---

# Jellyfin Integration

Sonzra is **not** a media server.

Jellyfin remains the backend.

Sonzra consumes:

- Jellyfin REST API
- Jellyfin WebSocket events

Expected features:

- Login
- Multiple servers
- User switching
- Library browsing
- Playback
- Queue
- Sessions
- Resume playback
- Favorites
- Recently played

Future:

- Lyrics
- Downloads
- Offline mode
- Casting
- Multi-room playback

---

# Branding

Name:

# Sonzra

The name should always appear as:

Sonzra

Never:

SONZRA

unless typography specifically requires uppercase.

---

# Visual Identity

Inspired by Jellyfin's aesthetic but **not** copying it.

Keywords:

- modern
- minimal
- geometric
- soft
- vibrant
- open-source
- community
- privacy
- self-hosted

---

# Color Palette

Primary

#7A5AF8

Primary Dark

#5C3FD6

Accent

#43D7C6

Background

#16161F

Surface

#252538

Text

#F6F6FA

---

# Logo

The logo is **NOT**:

- headphones
- speaker
- microphone
- musical note

Instead:

A stylized "S" made from audio waveforms.

The waveform should read as sound first.

The "S" should be discovered naturally.

Everything should work as:

- favicon
- app icon
- SVG
- monochrome
- dark mode
- light mode

---

# Dynamic Logo

One of the defining features of Sonzra is that the logo is alive.

The icon represents playback state.

Examples:

Idle

Static waveform.

Playing

Waveform gently animates.

Loading

Wave moves left to right.

Buffering

Wave pulses.

Connecting

Small cyan pulse travels through waveform.

Paused

Animation freezes.

Offline

Wave becomes flatter.

Error

Wave becomes red.

Animations should remain subtle.

---

# Design Language

Rounded corners.

Soft gradients.

Mostly flat.

SVG-first.

Prefer CSS animation.

Avoid skeuomorphism.

---

# Typography

Preferred fonts:

- Manrope
- Inter
- Geist
- Plus Jakarta Sans

---

# UX

The application should feel similar to:

- Spotify
- Apple Music
- Plexamp

But remain entirely server-rendered.

Use Turbo Frames.

Use Turbo Streams.

Avoid unnecessary page reloads.

---

# Audio

Support:

- Music
- Podcasts
- Audiobooks

Playback should continue between page navigations.

Player should become a persistent component.

---

# Rails Guidelines

Prefer:

Rails conventions

instead of:

custom architecture

Avoid unnecessary gems.

Prefer:

- ActiveRecord
- ActionCable
- Turbo
- Stimulus

before introducing third-party libraries.

---

# Components

Reusable UI components should exist for:

- Buttons
- Cards
- Album artwork
- Artist rows
- Queue
- Player
- Navigation
- Sidebar
- Toasts
- Dialogs

Keep components small.

---

# Accessibility

Support:

- keyboard navigation

- screen readers

- reduced motion

- dark mode

- high contrast

---

# Performance

Avoid unnecessary JavaScript.

Prefer:

Turbo Streams

instead of polling.

Lazy load images.

Cache album artwork.

---

# Mobile

Everything should be mobile-first.

Desktop should enhance the layout rather than define it.

Remember:

This project will eventually run inside Hotwire Native.

---

# Future Features

Music

Podcasts

Audiobooks

Downloads

Offline mode

Lyrics

Sleep timer

Playback speed

Bookmarks

Casting

Sync across devices

Multi-room playback

Android Auto

Apple CarPlay

Wearables

---

# Open Source

The project should be welcoming to contributors.

Code should be:

- readable

- conventional

- documented

- tested

Avoid clever solutions.

Prefer maintainability.

---

# Coding Style

Prefer readability over cleverness.

Small methods.

Small classes.

Good naming.

Use POROs when appropriate.

Avoid premature abstraction.

Follow Rails conventions.

---

# What Makes Sonzra Different

Sonzra is not trying to replace Jellyfin.

It is trying to become the best audio experience for Jellyfin.

The priorities are:

1. Beautiful UX

2. Fast server-rendered UI

3. Native feeling through Hotwire

4. Self-hosted

5. Open source

6. Privacy-first

7. Minimal JavaScript

8. Excellent mobile experience

---

# Instructions for AI Coding Agents

When implementing features:

- Follow Rails conventions first.
- Prefer Hotwire over JavaScript.
- Prefer Turbo Streams over custom WebSocket code.
- Keep Stimulus controllers focused and small.
- Avoid introducing frontend frameworks.
- Build reusable components.
- Write maintainable, idiomatic Ruby.
- Keep the codebase approachable for open-source contributors.
- Preserve the Sonzra visual identity and design language.
- Favor server-rendered interactions unless there is a compelling reason to move logic to the client.