## Do Input, Label and Textarea ship before the other seventeen components?

decider: Jonathan Simmons
options: first, as their own batch; in whichever batch they fall
default: first — Field, `Ui::FormBuilder` and Input Group all build on them, so settling their API early keeps three later pieces of work from reworking it
deadline: 2026-09-15

## How do control boundaries reach 3:1 when `--input` is 1.27–1.64:1 against every surface?

decider: Jonathan Simmons
options: darken `--input` in both modes in `ui-design-tokens` until a control boundary reaches 3:1 on every surface, leaving `--border` subtle for decoration; exempt control boundaries from the 3:1 rule, relying on labels and placement to identify the field; give form controls a second visual cue (a filled background) and keep `--input` as it is
default: darken `--input` in `ui-design-tokens` — the token contract already separates `input` (control boundaries) from `border` (decoration), so this is the token doing its job. It also darkens Button's outline border, which reads as the same control family
deadline: 2026-09-15

## How does dark `--destructive` reach 4.5:1 as text when it is 3.22–3.49:1 on dark surfaces today?

decider: Jonathan Simmons
options: lighten dark `--destructive` and give dark `--destructive-foreground` a dark label, as the tokens already did for dark `--primary`; add a separate kit-extension text token for destructive text; never use `--destructive` as a text colour, only as a fill
default: lighten dark `--destructive` and darken its foreground in `ui-design-tokens`, mirroring `--primary` — one precedent, no new token, and Button's destructive label contrast is already guarded by `test/system/button_test.rb`
deadline: 2026-09-15

## Do Alert and Badge gain success, warning and info variants in this scope?

decider: Jonathan Simmons
options: no, ship the default and destructive axes listed in spec.md § Behavior only; yes, add the `--success`/`--warning`/`--info` kit extensions and their variants here
default: no — `ui-design-tokens` rule 5 adds those tokens when a consumer needs them, and Toast in `ui-foundation-retrofit` is the first that does; adding them for Alert and Badge now is speculative
deadline: 2026-09-21
