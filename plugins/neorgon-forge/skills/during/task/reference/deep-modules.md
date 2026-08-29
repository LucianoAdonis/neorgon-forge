# Designing the shape of a module

Loaded when the work is not "make this behave differently" but "this is in the wrong shape".
The vocabulary below is deliberately small and used exactly: substituting a synonym is how a
design conversation stops being about anything.

## The terms

**Module**: anything with an interface and an implementation. Scale-agnostic on purpose: a
function, a class, a package, a whole site. _Avoid_: unit, component, service.

**Interface**: everything a caller must know to use the module correctly. Not just the type
signature: also the invariants, the ordering constraints, the error modes, the required
configuration, and the performance characteristics. _Avoid_: API, signature, both of which name
only the type-level surface and so make a wide interface look narrow.

**Implementation**: what is inside. Distinct from adapter: a thing can be a small adapter with
a large implementation, or a large adapter with a small one.

**Depth**: leverage at the interface. How much behaviour a caller can exercise per unit of
interface they have to learn. **Deep** is a lot of behaviour behind a small interface.
**Shallow** is an interface nearly as complicated as the implementation, which is a module that
has cost you a file and bought you nothing.

**Seam** (Michael Feathers): a place where behaviour can be altered without editing in that
place. Where the seam goes is its own decision, separate from what goes behind it. _Avoid_:
boundary, which is already taken by bounded context.

**Adapter**: a concrete thing satisfying an interface at a seam. Names a role, not a substance.

**Leverage**: what callers get from depth. One implementation paying back across N call sites
and M tests.

**Locality**: what maintainers get from depth. Change, bugs, knowledge and verification
concentrate in one place. Fixed once, fixed everywhere.

## The four questions

Ask these of an interface before defending it:

1. Can it have fewer entry points?
2. Can the parameters be simpler, or fewer, or harder to pass wrongly?
3. Can more of the complexity move inside?
4. Does the caller have to know the order to call things in? (If yes, the interface is wider
   than it looks, and step 3 has not been done.)

## Where this bites in a static fleet

The deep-module argument arrives from server codebases, and two of its shapes translate badly
to a repo of single-file HTML apps. Both are worth naming before applying any of the above:

- **A shared kit is a deep module, and vendoring is its adapter.** The Header and Footer Kits
  are the fleet's clearest example: a wide behaviour set behind `class="header-bar"` plus a few
  data attributes. That is why site-local header CSS is banned. A site that adds its own is not
  extending the module, it is widening the interface for everyone.
- **A wrapper that only forwards is shallow, and most "let's abstract this" proposals are that.**
  A module worth extracting hides a decision. One that hides a call is a rename with a file
  around it.

## The failure this prevents

The common bad refactor is not too little abstraction, it is a layer of shallow modules: six
files where each one's interface is as complicated as its body, so a reader now learns six
interfaces to understand one behaviour. Depth is the check. If splitting a thing does not make
the caller's job smaller, it made it larger.

Where this is the *finding* rather than the fix, say so and stop: a task that discovers the real
problem is the module's shape is a task whose honest report names that, rather than one that
quietly rewrites the architecture on the way past.
