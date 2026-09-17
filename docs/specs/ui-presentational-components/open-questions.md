## Do Input, Label and Textarea ship before the other seventeen components?

decider: Jonathan Simmons
options: first, as their own batch; in whichever batch they fall
default: first — Field, `Ui::FormBuilder` and Input Group all build on them, so settling their API early keeps three later pieces of work from reworking it
deadline: 2026-09-15

## Do Alert and Badge gain success, warning and info variants in this scope?

decider: Jonathan Simmons
options: no, ship the default and destructive axes listed in spec.md § Behavior only; yes, add the `--success`/`--warning`/`--info` kit extensions and their variants here
default: no — `ui-design-tokens` rule 5 adds those tokens when a consumer needs them, and Toast in `ui-foundation-retrofit` is the first that does; adding them for Alert and Badge now is speculative
deadline: 2026-09-21
