import { ChangeDetectionStrategy, Component, OnInit, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslatePipe } from '@ngx-translate/core';
import { ContentItemData, LearnService } from './learn.service';

@Component({
  selector: 'app-learn',
  imports: [ RouterLink, TranslatePipe ],
  templateUrl: './learn.html',
  styleUrl: './learn.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Learn implements OnInit {
  private readonly learnService = inject(LearnService);

  readonly items = signal<ContentItemData[]>([]);
  readonly loading = signal(true);
  readonly openItemId = signal<number | null>(null);

  async ngOnInit(): Promise<void> {
    this.items.set(await this.learnService.list());
    this.loading.set(false);
  }

  toggleOpen(item: ContentItemData): void {
    if (!item.unlocked) return;
    this.openItemId.set(this.openItemId() === item.id ? null : item.id);
  }

  async markComplete(item: ContentItemData, event: Event): Promise<void> {
    event.stopPropagation();
    const updated = await this.learnService.complete(item.id);
    this.items.update((list) => list.map((i) => (i.id === updated.id ? updated : i)));
  }
}
