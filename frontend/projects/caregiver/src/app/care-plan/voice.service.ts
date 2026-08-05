import { Injectable } from '@angular/core';

// BCP-47 tags for the app's five supported languages (Section 2). Best
// effort only — browsers vary in which voices they actually ship, and
// SpeechSynthesisUtterance.lang is just a hint the platform tries to
// match, per the product-owner decision to use the browser-native Web
// Speech API rather than a cloud TTS provider (ADR-0010).
const BCP47: Record<string, string> = { en: 'en-US', de: 'de-DE', tr: 'tr-TR', ru: 'ru-RU', ar: 'ar-SA' };

/**
 * Caregiver requirement #2 (post-M7, ADR-0010): "a voice instruction can
 * be given based on the information uploaded by the nurse." Wraps
 * `window.speechSynthesis` directly — no new dependency, no subprocessor.
 * Feature-detected so the UI can hide/disable the button gracefully where
 * unsupported (some browsers/embedded webviews lack it entirely).
 */
@Injectable({ providedIn: 'root' })
export class VoiceService {
  isSupported(): boolean {
    return typeof window !== 'undefined' && 'speechSynthesis' in window && typeof SpeechSynthesisUtterance !== 'undefined';
  }

  speak(text: string, language: string): boolean {
    if (!this.isSupported() || !text.trim()) return false;

    window.speechSynthesis.cancel(); // don't stack utterances if pressed again mid-speech
    const utterance = new SpeechSynthesisUtterance(text);
    utterance.lang = BCP47[language] ?? language;
    window.speechSynthesis.speak(utterance);
    return true;
  }

  stop(): void {
    if (this.isSupported()) window.speechSynthesis.cancel();
  }
}
