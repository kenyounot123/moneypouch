# Changelog

## [0.7.0](https://github.com/kenyounot123/moneypouch/compare/v0.6.0...v0.7.0) (2026-10-17)


### Features

* **overview:** show money in green and add sample paychecks as income ([#106](https://github.com/kenyounot123/moneypouch/issues/106)) ([391f0bb](https://github.com/kenyounot123/moneypouch/commit/391f0bb3b8c25032e7d1f886ba3d7ec9027f69a3))
* **overview:** summary chart follows the period and keeps bars on screen while one is in focus ([#104](https://github.com/kenyounot123/moneypouch/issues/104)) ([deda440](https://github.com/kenyounot123/moneypouch/commit/deda44063d594b4af2a5498fe4480934926b5b5b))
* **transactions:** replace the month footer with a back-to-top button ([#103](https://github.com/kenyounot123/moneypouch/issues/103)) ([fbc6581](https://github.com/kenyounot123/moneypouch/commit/fbc658115e302bf2bdd920e97d922084f6c4c669))


### Bug Fixes

* **transactions:** clear a category by saving an empty picker ([#107](https://github.com/kenyounot123/moneypouch/issues/107)) ([be84a00](https://github.com/kenyounot123/moneypouch/commit/be84a00da54b06a05d262866c98e6b4cdcdde818))

## [0.6.0](https://github.com/kenyounot123/moneypouch/compare/v0.5.0...v0.6.0) (2026-10-16)


### Features

* **settings:** download every transaction as a CSV file ([#95](https://github.com/kenyounot123/moneypouch/issues/95)) ([d63baf7](https://github.com/kenyounot123/moneypouch/commit/d63baf73fb6579c02c6e2efdc58f46dc011c50ff))
* **transactions:** hand-drawn row action icons and a clearer filter bar ([#100](https://github.com/kenyounot123/moneypouch/issues/100)) ([b4eeeb8](https://github.com/kenyounot123/moneypouch/commit/b4eeeb8e41e9d7f3dc9bb7a52c071c2fa45a8e41))


### Bug Fixes

* **import:** bring in transfers and multi-line notes, and skip rows already in the account ([#96](https://github.com/kenyounot123/moneypouch/issues/96)) ([8fc9de0](https://github.com/kenyounot123/moneypouch/commit/8fc9de0592cfb7ed33a028a24a7d5b517db6577d))
* **palette:** cover the scrollbar gutter with the scrim while a dialog is open ([#99](https://github.com/kenyounot123/moneypouch/issues/99)) ([39b5ff3](https://github.com/kenyounot123/moneypouch/commit/39b5ff307e87ddcad713ed38cf1e6544fc27af44))


### Performance Improvements

* **transactions:** refresh other screens when a change commits ([#102](https://github.com/kenyounot123/moneypouch/issues/102)) ([aa076e9](https://github.com/kenyounot123/moneypouch/commit/aa076e9f66418ed1364bbe9d31413df4bde4aeaf))
* **transactions:** render a busy month in pages of whole days ([#101](https://github.com/kenyounot123/moneypouch/issues/101)) ([113e30b](https://github.com/kenyounot123/moneypouch/commit/113e30b3afb711118712aef87ba055619cf31f17))

## [0.5.0](https://github.com/kenyounot123/moneypouch/compare/v0.4.0...v0.5.0) (2026-10-16)


### Features

* **import:** import expense history from an Excel or CSV file ([#92](https://github.com/kenyounot123/moneypouch/issues/92)) ([04c099c](https://github.com/kenyounot123/moneypouch/commit/04c099cf3ecbc44f895ca0804702dd9699801010))
* **import:** read a CSV or xlsx file and turn its rows into transactions ([#91](https://github.com/kenyounot123/moneypouch/issues/91)) ([effcaad](https://github.com/kenyounot123/moneypouch/commit/effcaad4b4f07066478f2beb0a9c15459cf7e9dc))
* **overview:** chart slot with a spending and summary toggle, bank count badge, and Show all headers ([#86](https://github.com/kenyounot123/moneypouch/issues/86)) ([cbb9297](https://github.com/kenyounot123/moneypouch/commit/cbb929775042050ae2c9518e515c3a5d296a2d43))
* **transactions:** add an Excluded flag that keeps a row listed but out of every total ([#89](https://github.com/kenyounot123/moneypouch/issues/89)) ([4e15d4f](https://github.com/kenyounot123/moneypouch/commit/4e15d4f134a5227f94b7e940669d78ede8fb1805))


### Bug Fixes

* **import:** one layout for both steps, right-aligned amounts, toast above the composer ([#93](https://github.com/kenyounot123/moneypouch/issues/93)) ([cc57b43](https://github.com/kenyounot123/moneypouch/commit/cc57b43f60eab0dff2c592ce24a075460eaee36f))

## [0.4.0](https://github.com/kenyounot123/moneypouch/compare/v0.3.0...v0.4.0) (2026-10-13)


### Features

* **transactions:** turn /transactions into a month ledger ([#78](https://github.com/kenyounot123/moneypouch/issues/78)) ([131a5d8](https://github.com/kenyounot123/moneypouch/commit/131a5d874e70ab9024305bc04c4e72f85d47014c))

## [0.3.0](https://github.com/kenyounot123/moneypouch/compare/v0.2.0...v0.3.0) (2026-10-13)


### Features

* **palette:** dim the page behind the palette to 40% in light mode ([#74](https://github.com/kenyounot123/moneypouch/issues/74)) ([c12c8ff](https://github.com/kenyounot123/moneypouch/commit/c12c8ff4d9bb824a5328333db0f39cc2aaa002ca))


### Bug Fixes

* **transactions:** keep the row height when the category picker opens ([#76](https://github.com/kenyounot123/moneypouch/issues/76)) ([ef5e194](https://github.com/kenyounot123/moneypouch/commit/ef5e1941e44ed6d5ce6381880fbc3f35c129d39b))

## [0.2.0](https://github.com/kenyounot123/moneypouch/compare/v0.1.0...v0.2.0) (2026-10-12)


### Features

* **docker:** support installing with ONCE ([#69](https://github.com/kenyounot123/moneypouch/issues/69)) ([a38481a](https://github.com/kenyounot123/moneypouch/commit/a38481a3e79838003b24514f9d7f22404cd662c1))

## 0.1.0 (2026-10-12)


### Features

* **brand:** use the app's pouch for the favicon and app icon ([#66](https://github.com/kenyounot123/moneypouch/issues/66)) ([0fe2fcf](https://github.com/kenyounot123/moneypouch/commit/0fe2fcf95e25be7215d5e4f14fad0474c161caa2))
* **release:** publish a Docker image to GHCR on each release ([#64](https://github.com/kenyounot123/moneypouch/issues/64)) ([bdd57ff](https://github.com/kenyounot123/moneypouch/commit/bdd57ff5fdc2ef0e5afa9d2bb34a24a6c55dae01))
