// «القرآن الكريم» — component props (documentation). Global: window.Quran. Needs React 18 on the page.
import type { ReactNode, CSSProperties } from 'react';

export type IconName = 'home' | 'mushaf' | 'listen' | 'study' | 'search' | 'bookmark' | 'download' | 'night' | 'settings' | 'repeat' | 'index' | 'khatma' | 'next' | 'previous' | 'more' | 'alert' | 'check' | 'close' | 'play' | 'pause' | 'mic' | 'eye' | 'sort' | 'minus' | 'plus' | 'context';
export type TajweedRule = 'ghunna' | 'idgham' | 'ikhfa' | 'iqlab' | 'qalqala' | 'madd-tabii' | 'madd-wajib' | 'madd-lazim';

/** 255 → «٢٥٥». */
export function arabicDigits(n: number | string): string;
/** Correct Arabic count of times: مرة واحدة، مرتان، ٧ مرات، ١١ مرة. */
export function timesCount(n: number): string;
/** Correct Arabic count of ayat: آية واحدة، آيتان، ٧ آيات، ٢٨٦ آية. */
export function ayahCount(n: number): string;
export const iconNames: IconName[];
export const TAJWEED_RULES: Record<TajweedRule, { name: string; desc: string; line: string; pos: 'under' | 'over' }>;

export interface MarkProps { size?: number; variant?: 'paper' | 'emerald' | 'dark' | 'mono'; label?: string; decorative?: boolean }
export interface LockupProps { size?: number; onEmerald?: boolean; stacked?: boolean }
export interface IconProps { name: IconName; size?: number; label?: string; className?: string; style?: CSSProperties }
export interface StarOutlineProps { size?: number; stroke?: number; className?: string }
export interface ButtonProps extends Omit<React.ButtonHTMLAttributes<HTMLButtonElement>, 'type'> { variant?: 'primary' | 'outline' | 'tonal' | 'text'; icon?: IconName; children: ReactNode }
export interface IconButtonProps extends Omit<React.ButtonHTMLAttributes<HTMLButtonElement>, 'type'> { icon: IconName; label: string; tone?: 'plain' | 'tint' | 'solid'; size?: number; iconSize?: number }
export interface LevelSwitchProps { value?: number; defaultValue?: number; onChange?: (index: number) => void; options?: string[]; label?: string }
export interface TagProps { shape?: 'circle' | 'square' | 'diamond' | 'ring'; color?: string; selected?: boolean; children: ReactNode; onClick?: () => void }
export interface SwitchProps { checked?: boolean; defaultChecked?: boolean; onChange?: (on: boolean) => void; label: ReactNode }
export interface AyahMarkerProps { number: number; playing?: boolean; size?: number }
export interface QuranTextProps { children: ReactNode; size?: 'page' | 'ayah' | 'focus' | 'compact'; align?: 'justify' | 'center' | 'start'; as?: string }
export interface SurahHeaderProps { name: string; size?: 'md' | 'lg'; info?: ReactNode }
export interface AyahRowProps { number: number; children: ReactNode; onPlay?: () => void; onBookmark?: () => void; onStudy?: () => void }
export interface SurahListItemProps { number: number; name: string; revelation: 'مكية' | 'مدنية'; ayat: number; page: number; lastRead?: boolean; onClick?: () => void }
export interface ProgressBarProps { value?: number; tone?: 'primary' | 'player'; height?: number; label?: string }
export interface MiniPlayerProps { title: ReactNode; reciter: ReactNode; progress?: number; speed?: string; playing?: boolean; repeat?: number }
export interface ContinueCardProps { label?: string; title: ReactNode; meta: ReactNode; progress?: number; action?: string; onClick?: () => void }
export interface ResourceRowProps { title: ReactNode; status?: 'downloaded' | 'downloading' | 'available'; size?: ReactNode; progress?: number; onAction?: () => void }
export interface TajweedKeyProps { rule: TajweedRule; compact?: boolean }
export interface TajweedProps { rule: TajweedRule; children: ReactNode }
export interface TajweedLineProps { rule: TajweedRule; width?: number }
export interface TabBarProps { active?: 'home' | 'mushaf' | 'listen' | 'study' | 'more'; items?: [IconName, string][]; onChange?: (key: string) => void }
export interface WordSheetProps { word: ReactNode; position?: ReactNode; tabs?: string[]; activeTab?: number; rows?: [string, ReactNode][]; note?: ReactNode }

export interface SearchFieldProps { value?: string; defaultValue?: string; onChange?: (text: string) => void; onVoice?: () => void; placeholder?: string; label?: string }
export interface ModeChipsProps { options?: string[]; value?: number; defaultValue?: number; onChange?: (index: number) => void; label?: string }
export interface SearchSummaryProps { title: ReactNode; count: ReactNode; sort?: string; onSort?: () => void }
export interface MatchProps { children: ReactNode }
export interface SearchResultProps { reference: ReactNode; children: ReactNode; clamp?: boolean; onContext?: () => void; onOpen?: () => void }
export interface ContextSheetProps { title?: string; subtitle?: string; reference: ReactNode; options?: string[]; value?: number; defaultValue?: number; onChange?: (index: number) => void; children: ReactNode; onOpen?: () => void; onPlay?: () => void }
export interface RepeatDotsProps { total?: number; done?: number; label?: string }
export interface SessionStatusProps { step: number; steps: number; ayah: ReactNode; repetition: number; total?: number }
export interface ConcealedTextProps { /** The ayah exactly as the approved source gives it. */ children: string; revealed?: boolean; label?: string }
export interface SessionBarProps { title: ReactNode; detail?: ReactNode; playing?: boolean; onToggle?: () => void; onNext?: () => void }
export interface StepperProps { label: string; value?: number; defaultValue?: number; min?: number; max?: number; unit?: string; onChange?: (n: number) => void }
export interface PlanStepProps { state?: 'done' | 'current' | 'next'; title: ReactNode; repeats: ReactNode; merge?: boolean }

export function Mark(props: MarkProps): JSX.Element;
export function Lockup(props: LockupProps): JSX.Element;
export function Icon(props: IconProps): JSX.Element;
export function StarOutline(props: StarOutlineProps): JSX.Element;
export function Button(props: ButtonProps): JSX.Element;
export function IconButton(props: IconButtonProps): JSX.Element;
export function LevelSwitch(props: LevelSwitchProps): JSX.Element;
export function Tag(props: TagProps): JSX.Element;
export function Switch(props: SwitchProps): JSX.Element;
export function AyahMarker(props: AyahMarkerProps): JSX.Element;
export function QuranText(props: QuranTextProps): JSX.Element;
export function SurahHeader(props: SurahHeaderProps): JSX.Element;
export function AyahRow(props: AyahRowProps): JSX.Element;
export function SurahListItem(props: SurahListItemProps): JSX.Element;
export function ProgressBar(props: ProgressBarProps): JSX.Element;
export function MiniPlayer(props: MiniPlayerProps): JSX.Element;
export function ContinueCard(props: ContinueCardProps): JSX.Element;
export function ResourceRow(props: ResourceRowProps): JSX.Element;
export function TajweedKey(props: TajweedKeyProps): JSX.Element;
export function Tajweed(props: TajweedProps): JSX.Element;
export function TajweedLine(props: TajweedLineProps): JSX.Element;
export function TabBar(props: TabBarProps): JSX.Element;
export function WordSheet(props: WordSheetProps): JSX.Element;
export function SearchField(props: SearchFieldProps): JSX.Element;
export function ModeChips(props: ModeChipsProps): JSX.Element;
export function SearchSummary(props: SearchSummaryProps): JSX.Element;
export function Match(props: MatchProps): JSX.Element;
export function SearchResult(props: SearchResultProps): JSX.Element;
export function ContextSheet(props: ContextSheetProps): JSX.Element;
export function RepeatDots(props: RepeatDotsProps): JSX.Element;
export function SessionStatus(props: SessionStatusProps): JSX.Element;
export function ConcealedText(props: ConcealedTextProps): JSX.Element;
export function SessionBar(props: SessionBarProps): JSX.Element;
export function Stepper(props: StepperProps): JSX.Element;
export function PlanStep(props: PlanStepProps): JSX.Element;
