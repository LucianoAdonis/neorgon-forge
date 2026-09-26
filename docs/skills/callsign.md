# callsign

A codename with rules behind it: projects answer to an acronym, tools to a weapon's name.

## What it does

`callsign` runs the command line that ships in the Callsign site repo, so a name it
offers is the name https://callsign.neorgon.com shows for the same words. It picks
the slot from what is being named (a frontend is a head, a scheduler is a missile
launcher), forges three candidates from three different house grammars, and hands
each back with its designation, acronyms, reading, grammar version and a link that
reopens it.

## When to reach for it

Type `/callsign`, or the agent reaches for it when asked for a codename, a service
name or an acronym in Armored Core style. It needs a checkout of callsign-site;
without one it stops with exit 2 rather than making a name up. Inside the Neorgon
monorepo, `/new-project` can use it for subdomain candidates, from the plain
acronyms only.

## Names are versioned

A plate is a pure function of the words, the house, the slot, the roll and the
grammar version. Adding one word to a word pool renames about half of that house's
plates, so the site numbers its grammars, stamps the number into every link and
export, and a link from another grammar opens with a notice instead of silently
different names. When a name must never change, keep the designation text as well
as the link.

## It's working if

- The designation it hands back is the first plate its link opens.
- An unknown house or slot, or a missing checkout, ends in exit 2 and no name.
- Nothing it offers is a real in-game part name.
