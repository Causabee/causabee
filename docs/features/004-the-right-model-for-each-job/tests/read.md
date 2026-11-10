# F004 · Reading what comes in — Sol against the models it may move to

## Sol (gpt-6.1-sol)

- Items read: 93 of 93; in the matter the demo puts them in: 75
- Cost of the run: $0.674

## Terra (gpt-6.1-terra)

- Items read: 93 of 93; in the matter the demo puts them in: 71
- Cost of the run: $0.3617
- **In another matter than Sol's: 7** (bar: none)
- **Sol's tasks found: 44 of 53; Sol's dates found: 30 of 34 — 85.1%** (bar: at least 95%)
- Found that Sol did not: 5 — each to be read against the item: a fact Sol missed, or invented (bar: none invented)
- Failed where Sol did not, or the other way: 0

### In another matter

| Item | The demo's matter | Sol | This model |
|---|---|---|---|
| Membership contract | mums-gym | mums-gym | None |
| Mortgage: documents we need | flat-linden-street | mortgage-2027 | mortgagefinancing |
| Your travel insurance offer | lisbon-october | lisbon-october | None |
| Financing commitment is ready | flat-linden-street | flat-linden-street | financingcommitment |
| Contract draft: please sign and return by 2 October | care-for-helga | care-for-Helga Voss | visitscontract |
| Prescription for the bath seat is ready | care-for-helga | care-for-Helga Voss | None |
| Rate comparison | mortgage-2027 | mortgage-2027 | None |

### Found, but not by Sol

| Item | Kind | This model | Sol's |
|---|---|---|---|
| Group chat: who brings what? | task | Answer the question about a garden tap for testing | Bring the bottles for the rainwater filter.; Clarify who has a garden tap for testing. |
| Application received: care level for Helga Voss | task | Receive the insurer's decision on the care level | Arrange a medical service visit for Helga Voss. |
| Repair estimate for your car | task | Send the repair estimate to ClearRoad | — |
| Re: Arrival time? | task | Marta Sousa die Ankunftszeit mitteilen | Send Marta Sousa the arrival time. |
| Parking for the van? | task | Ask Ms. Adler in time to use her drive for the van on Wednesday morning. | — |

### Sol found, this model did not

| Item | Kind | Sol | This model's |
|---|---|---|---|
| After your mother's hospital stay: what she needs | task | Arrange help with showering and shopping for Helga Voss for about six weeks. | — |
| Re: Who does what this week? | task | Ask Uncle Karl about covering Thursday. | — |
| Casa do Largo: booking confirmed | date | 2026-10-10 · Free cancellation ends | — |
| Group chat: who brings what? | task | Bring the bottles for the rainwater filter. | Answer the question about a garden tap for testing |
| Group chat: who brings what? | task | Clarify who has a garden tap for testing. | Answer the question about a garden tap for testing |
| Application received: care level for Helga Voss | task | Arrange a medical service visit for Helga Voss. | Receive the insurer's decision on the care level |
| Deposit reminder | date | 2026-10-10 · Date hold expires | — |
| Visit by the medical service on 6 October | task | Attend the assessment visit as a family member. (due 2026-10-06) | — |
| Handover of the building documents | task | Hand over the building files. (due 2026-12-31) | Provide the 2025 statement |
| Your travel insurance offer | date | 2026-10-12 · Travel insurance offer expires | — |
| Reading of the meter on moving day | date | 2026-10-31 · Send the meter reading | — |
| Re: Arrival time? | task | Send Marta Sousa the arrival time. | Marta Sousa die Ankunftszeit mitteilen |
| Feedback on the draft poster | task | Shorten the poster text to three short sentences under each picture. | Shorten the poster text and show the new layout to Ms. Okafor before printing |

## Luna (gpt-6-luna)

- Items read: 93 of 93; in the matter the demo puts them in: 75
- Cost of the run: $0.0544
- **In another matter than Sol's: 2** (bar: none)
- **Sol's tasks found: 20 of 53; Sol's dates found: 29 of 34 — 56.3%** (bar: at least 95%)
- Found that Sol did not: 31 — each to be read against the item: a fact Sol missed, or invented (bar: none invented)
- Failed where Sol did not, or the other way: 0

### In another matter

| Item | The demo's matter | Sol | This model |
|---|---|---|---|
| Financing commitment is ready | flat-linden-street | flat-linden-street | mortgage-2027 |
| Donation receipt | tax-return-2025 | None | tax-return-2025 |

### Found, but not by Sol

| Item | Kind | This model | Sol's |
|---|---|---|---|
| Who does what this week? | task | Den Wochenanfang in Mums Betreuung abdecken | Cover Mum's care at the start of the week. |
| Re: Who does what this week? | task | Uncle Karl wegen Donnerstag fragen | Ask Uncle Karl about covering Thursday. |
| Science fair 2026: project briefing for class 9b | task | Die einseitige schriftliche Zusammenfassung für die Messe erstellen (due 2026-10-07) | Submit the one-page project summary (due 2026-10-07) |
| Topic approval form: parents please sign | task | Das Formular zur Themenfreigabe unterschreiben | Sign the topic approval form.; Hand in the signed topic approval form. |
| Topic approval form: parents please sign | task | Das unterschriebene Formular abgeben | Sign the topic approval form.; Hand in the signed topic approval form. |
| Your offer was accepted | task | Schriftliche Finanzierungszusage bei der Bank einholen | Provide the sellers with a written financing commitment from the bank within three weeks. |
| Tax return 2025: what I need from you | task | Jana Falk die Lohnsteuerbescheinigung, Bank- und Zinsbescheinigungen, Spendenbelege und Homeoffice-Kosten schicken (due 2026-10-31) | Send Jana Falk the employer's tax certificate, bank and interest statements, donation receipts and home office costs. |
| Quote: moving on 21 October | task | Decide whether to accept Carry & Co's moving offer. | — |
| You are coming!! Dinner at mine? | task | Adresse und Türcode für das Abendessen mitteilen | Send the dinner address and door code |
| Live band or DJ? | task | Zwischen Liveband und DJ für die Hochzeit entscheiden (due 2026-11-30) | Tell Jule Brandt whether to choose the live band or DJ. (due 2026-11-30) |
| Offer: management of Elm Court 51 from 1 January | task | Kessler eine Vollmacht für die Verwaltung von Elm Court 51 erteilen | Provide a power of attorney for Kessler to manage the building. |
| Moving your internet connection | task | Internetanschluss für den Umzug kostenlos ummelden (due 2026-11-02) | Request the internet connection move at least four weeks before moving. |
| Moving your internet connection | date | 2026-11-02 · Internetanschluss spätestens vier Wochen vor dem Umzug ummelden | — |
| Repair estimate for your car | task | Kostenvoranschlag an ClearRoad weiterleiten | — |
| Handover of the building documents | date | 2026-12-31 · Handover of the building files | — |
| Handover of the flat: what to prepare | task | Wände vor der Übergabe weiß streichen | Repaint the walls white before handover.; Bring all keys, including the cellar key, to the handover. |
| Handover of the flat: what to prepare | task | Alle Schlüssel einschließlich des Kellerschlüssels zur Übergabe mitbringen | Repaint the walls white before handover.; Bring all keys, including the cellar key, to the handover. |
| Civil ceremony: documents | task | Beide Ausweise, Geburtsurkunden und Wohnsitznachweise zum vorbereitenden Termin mitbringen. | Bring ID, birth certificates and proof of residence for both of you to the preparatory appointment. |
| Reminder: written summary due 7 October | task | Zusammenfassung einige Tage vor dem 7. Oktober an Ms. Okafor schicken | Send the summary to Ms. Okafor a few days before the deadline.; Send the poster to print only after Ms. Okafor approves the layout. |
| Reminder: written summary due 7 October | task | Poster nach Genehmigung des Layouts in den Druck geben | Send the summary to Ms. Okafor a few days before the deadline.; Send the poster to print only after Ms. Okafor approves the layout. |
| Owners' group: vote on Kessler | task | Hartmann um die Erklärung für 2025 bitten | Ask Hartmann for the 2025 statement before the vote on Kessler. |
| Owners' group: vote on Kessler | date | 2026-11-19 19:00 · Owners' meeting: vote on Kessler | — |
| Arrival time? Key box and tram tips | task | Marta Sousa die Ankunftszeit der Familie mitteilen | Send the family's arrival time to Marta Sousa. |
| Draft of the purchase contract | task | Fragen zum Kaufvertragsentwurf an das Notariat senden | Review the purchase contract draft and send questions to Office of Dr. Wendt before signing (due 2026-10-12) |
| Reading of the meter on moving day | task | Zählerstand und neue Adresse an Northlight Energy senden (due 2026-10-31) | Send Northlight Energy the meter reading and new address (due 2026-10-31) |
| Your order is ready for pickup | task | Filter sand and clear tubing im Geschäft abholen | Pick up the filter sand and clear tubing from the store. |
| Your request: still in review | date | 2026-10-14 · Decision on whether the shower may be moved | — |
| Re: Arrival time? | task | Marta Sousa die Ankunftszeit mitteilen | Send Marta Sousa the arrival time. |
| Feedback on the draft poster | task | Postertext auf drei kurze Sätze unter jedem Bild kürzen und Okafor das neue Layout vor dem Druck zeigen | Shorten the poster text to three short sentences under each picture.; Send the revised poster layout to Ms. Okafor before printing. |
| Please confirm your bank details | task | Kontoinhaber und IBAN für die Zahlung bestätigen | Confirm the account holder and IBAN to Sabine Ott. |
| Parking for the van? | task | Ask Adler to use her driveway for the van on Wednesday morning | — |

### Sol found, this model did not

| Item | Kind | Sol | This model's |
|---|---|---|---|
| After your mother's hospital stay: what she needs | task | Arrange help with showering and shopping for Helga Voss for about six weeks. | — |
| Who does what this week? | task | Cover Mum's care at the start of the week. | Den Wochenanfang in Mums Betreuung abdecken |
| Re: Who does what this week? | task | Ask Uncle Karl about covering Thursday. | Uncle Karl wegen Donnerstag fragen |
| Science fair 2026: project briefing for class 9b | task | Submit the one-page project summary (due 2026-10-07) | Die einseitige schriftliche Zusammenfassung für die Messe erstellen (due 2026-10-07) |
| Topic approval form: parents please sign | task | Sign the topic approval form. | Das Formular zur Themenfreigabe unterschreiben; Das unterschriebene Formular abgeben |
| Topic approval form: parents please sign | task | Hand in the signed topic approval form. | Das Formular zur Themenfreigabe unterschreiben; Das unterschriebene Formular abgeben |
| Your offer was accepted | task | Provide the sellers with a written financing commitment from the bank within three weeks. | Schriftliche Finanzierungszusage bei der Bank einholen |
| Tax return 2025: what I need from you | task | Send Jana Falk the employer's tax certificate, bank and interest statements, donation receipts and home office costs. | Jana Falk die Lohnsteuerbescheinigung, Bank- und Zinsbescheinigungen, Spendenbelege und Homeoffice-Kosten schicken (due 2026-10-31) |
| Casa do Largo: booking confirmed | date | 2026-10-10 · Free cancellation ends | — |
| Group chat: who brings what? | task | Bring the bottles for the rainwater filter. | — |
| Group chat: who brings what? | task | Clarify who has a garden tap for testing. | — |
| Application received: care level for Helga Voss | task | Arrange a medical service visit for Helga Voss. | — |
| Quote: moving on 21 October | date | 2026-10-07 · Moving quote expires | — |
| You are coming!! Dinner at mine? | task | Send the dinner address and door code | Adresse und Türcode für das Abendessen mitteilen |
| Live band or DJ? | task | Tell Jule Brandt whether to choose the live band or DJ. (due 2026-11-30) | Zwischen Liveband und DJ für die Hochzeit entscheiden (due 2026-11-30) |
| Offer: management of Elm Court 51 from 1 January | task | Provide a power of attorney for Kessler to manage the building. | Kessler eine Vollmacht für die Verwaltung von Elm Court 51 erteilen |
| Moving your internet connection | task | Request the internet connection move at least four weeks before moving. | Internetanschluss für den Umzug kostenlos ummelden (due 2026-11-02) |
| Survey of the flat: short report | task | Have the bedroom windows resealed within two years. | — |
| Deposit reminder | date | 2026-10-10 · Date hold expires | — |
| Visit by the medical service on 6 October | task | Attend the assessment visit as a family member. (due 2026-10-06) | — |
| Management contract, draft | task | Approve the draft management contract with Kessler at the owners' meeting. | — |
| Handover of the building documents | task | Hand over the building files. (due 2026-12-31) | Send the 2025 statement |
| Handover of the flat: what to prepare | task | Repaint the walls white before handover. | Wände vor der Übergabe weiß streichen; Alle Schlüssel einschließlich des Kellerschlüssels zur Übergabe mitbringen |
| Handover of the flat: what to prepare | task | Bring all keys, including the cellar key, to the handover. | Wände vor der Übergabe weiß streichen; Alle Schlüssel einschließlich des Kellerschlüssels zur Übergabe mitbringen |
| Civil ceremony: documents | task | Bring ID, birth certificates and proof of residence for both of you to the preparatory appointment. | Beide Ausweise, Geburtsurkunden und Wohnsitznachweise zum vorbereitenden Termin mitbringen. |
| Reminder: written summary due 7 October | task | Send the summary to Ms. Okafor a few days before the deadline. | Zusammenfassung einige Tage vor dem 7. Oktober an Ms. Okafor schicken; Poster nach Genehmigung des Layouts in den Druck geben |
| Reminder: written summary due 7 October | task | Send the poster to print only after Ms. Okafor approves the layout. | Zusammenfassung einige Tage vor dem 7. Oktober an Ms. Okafor schicken; Poster nach Genehmigung des Layouts in den Druck geben |
| Owners' group: vote on Kessler | task | Ask Hartmann for the 2025 statement before the vote on Kessler. | Hartmann um die Erklärung für 2025 bitten |
| Arrival time? Key box and tram tips | task | Send the family's arrival time to Marta Sousa. | Marta Sousa die Ankunftszeit der Familie mitteilen |
| Draft of the purchase contract | task | Review the purchase contract draft and send questions to Office of Dr. Wendt before signing (due 2026-10-12) | Fragen zum Kaufvertragsentwurf an das Notariat senden |
| Draft of the purchase contract | date | 2026-10-12 · Signing the purchase contract | 2026-10-12 · Signing at the notary |
| Reading of the meter on moving day | task | Send Northlight Energy the meter reading and new address (due 2026-10-31) | Zählerstand und neue Adresse an Northlight Energy senden (due 2026-10-31) |
| Your order is ready for pickup | task | Pick up the filter sand and clear tubing from the store. | Filter sand and clear tubing im Geschäft abholen |
| Re: Arrival time? | task | Send Marta Sousa the arrival time. | Marta Sousa die Ankunftszeit mitteilen |
| Feedback on the draft poster | task | Shorten the poster text to three short sentences under each picture. | Postertext auf drei kurze Sätze unter jedem Bild kürzen und Okafor das neue Layout vor dem Druck zeigen |
| Feedback on the draft poster | task | Send the revised poster layout to Ms. Okafor before printing. | Postertext auf drei kurze Sätze unter jedem Bild kürzen und Okafor das neue Layout vor dem Druck zeigen |
| Please have these documents ready for the visit | date | 2026-10-06 · Care visit | 2026-10-06 · Visit related to Mum's care |
| Please confirm your bank details | task | Confirm the account holder and IBAN to Sabine Ott. | Kontoinhaber und IBAN für die Zahlung bestätigen |

