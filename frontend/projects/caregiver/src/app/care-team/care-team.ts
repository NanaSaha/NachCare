import { ChangeDetectionStrategy, Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { TranslatePipe, TranslateService } from '@ngx-translate/core';
import { EmergencyBlock } from 'shared';
import { CareTeamService } from './care-team.service';
import { LanguageService } from '../language/language.service';
import { MessagesService } from '../messages/messages.service';

const LANGUAGES = [ 'en', 'de', 'tr', 'ru', 'ar' ] as const;

@Component({
  selector: 'app-care-team',
  imports: [ RouterLink, TranslatePipe, EmergencyBlock, FormsModule ],
  templateUrl: './care-team.html',
  styleUrl: './care-team.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class CareTeam implements OnInit {
  private readonly careTeamService = inject(CareTeamService);
  private readonly languageService = inject(LanguageService);
  private readonly translate = inject(TranslateService);
  private readonly messagesService = inject(MessagesService);

  readonly languages = LANGUAGES;
  readonly siteName = signal<string | null>(null);
  readonly siteInfoFailed = signal(false);

  // Product-owner feedback item #3: "send an update to the care team"
  // composer — a caregiver-authored Message, optional image/video
  // attachment (ADR-0011). Lives on this page per the existing
  // `careTeam.messageHint` copy, which already told caregivers this is
  // where they'd do it (the hint just had nothing behind it before now).
  readonly updateText = signal('');
  readonly updateMedia = signal<File | null>(null);
  readonly updateMediaPreviewUrl = signal<string | null>(null);
  readonly sending = signal(false);
  readonly sendError = signal<string | null>(null);
  readonly sent = signal(false);

  currentLanguage(): string {
    return this.translate.currentLang() || 'en';
  }

  async ngOnInit(): Promise<void> {
    // Best-effort only (R4): the emergency block above this call in the
    // template renders unconditionally, with zero HTTP calls of its own —
    // this section is allowed to fail without affecting it.
    try {
      const data = await this.careTeamService.get();
      this.siteName.set(data.site_name);
    } catch {
      this.siteInfoFailed.set(true);
    }
  }

  async selectLanguage(lang: string): Promise<void> {
    await this.languageService.switchTo(lang);
  }

  onMediaSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    this.setMediaFile(input.files?.[0] ?? null);
  }

  removeMedia(): void {
    this.setMediaFile(null);
  }

  private setMediaFile(file: File | null): void {
    const previous = this.updateMediaPreviewUrl();
    if (previous) URL.revokeObjectURL(previous);

    this.updateMedia.set(file);
    this.updateMediaPreviewUrl.set(file ? URL.createObjectURL(file) : null);
  }

  async sendUpdate(): Promise<void> {
    const text = this.updateText().trim();
    const media = this.updateMedia();
    if (!text && !media) return;

    this.sending.set(true);
    this.sendError.set(null);
    try {
      await this.messagesService.send(text, media);
      this.updateText.set('');
      this.removeMedia();
      this.sent.set(true);
    } catch {
      this.sendError.set('careTeam.update.sendFailed');
    } finally {
      this.sending.set(false);
    }
  }
}
