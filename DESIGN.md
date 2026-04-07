# Design System Strategy: The Editorial Scholar

## 1. Overview & Creative North Star
The North Star for this design system is **"The Editorial Scholar."** 

Most language apps feel like games—cluttered, loud, and frantic. We are pivoting toward a high-end, editorial experience that treats language learning as a pursuit of craft. By utilizing intentional asymmetry, deep tonal layering, and sophisticated serif/sans-serif pairings, we create a "Digital Atelier." This system moves beyond the "app" feel into a "publication" feel, where whitespace isn't just empty—it's a deliberate structural element that gives the learner's mind room to breathe.

## 2. Colors & Tonal Architecture
We move away from the "bordered box" mentality. Our palette is anchored in professional blues and organic greens, executed through a philosophy of soft transitions rather than hard separations.

### The "No-Line" Rule
**Explicit Instruction:** Designers are prohibited from using 1px solid borders for sectioning or containment. 
*   **The Alternative:** Boundaries must be defined solely through background color shifts. For example, a `surface-container-low` section sitting on a `surface` background provides a sophisticated, "melted" transition that looks more premium than a hard line.

### Surface Hierarchy & Nesting
Treat the UI as a series of physical layers, like stacked sheets of fine, heavy-weight paper.
*   **Base:** `surface` (#f7f9fb)
*   **Lowest Importance:** `surface-container-low` (#f2f4f6)
*   **Active/Floating Cards:** `surface-container-lowest` (#ffffff)
*   **Nesting Strategy:** Use `surface-container-high` for sidebar navigation or utility panels to "recess" them into the background, allowing the central content (on `surface`) to feel like it is advancing toward the user.

### The "Glass & Signature" Rule
To elevate the experience, floating navigation or overlay modals should use **Glassmorphism**. Apply `surface` with 80% opacity and a `backdrop-blur` of 12px–20px. 
*   **Signature Textures:** For primary CTAs (like "Start Lesson"), do not use flat hex codes. Apply a subtle linear gradient from `primary` (#00478d) to `primary-container` (#005eb8) at a 135-degree angle. This adds a "lithographic" depth that flat UI cannot replicate.

## 3. Typography: The Linguistic Dual-Key
We use a "Dual-Key" system to distinguish between the interface (the tool) and the language (the content).

*   **UI/Interface (Manrope & Inter):** Used for navigation and labels. **Manrope** provides a geometric but warm authority for displays, while **Inter** ensures maximum legibility for tiny metadata.
*   **Content/Language (Newsreader):** All foreign language text and primary reading material must use **Newsreader**. This high-end serif evokes a literary tradition, signaling to the user that the text they are reading is "precious" and worthy of focus.

| Level | Token | Font | Size | Weight |
| :--- | :--- | :--- | :--- | :--- |
| **Display** | `display-lg` | Manrope | 3.5rem | 700 (Bold) |
| **Headline** | `headline-md` | Manrope | 1.75rem | 600 (Semi-Bold) |
| **Lesson Title**| `title-lg` | Newsreader | 1.375rem | 500 (Medium) |
| **Foreign Text** | `body-lg` | Newsreader | 1.0rem | 400 (Regular) |
| **UI Labels** | `label-md` | Inter | 0.75rem | 500 (Medium) |

## 4. Elevation & Depth
In this system, depth is a function of light and tone, not structure.

*   **Tonal Layering:** Avoid shadows for static cards. Instead, stack `surface-container-lowest` cards on top of a `surface-container-low` background. The 2% difference in luminosity is enough for the human eye to perceive depth.
*   **Ambient Shadows:** If an element must float (e.g., a vocabulary pop-over), use a "Whisper Shadow":
    *   `box-shadow: 0 10px 40px -10px rgba(25, 28, 30, 0.08);`
    *   The shadow color is derived from `on-surface` (#191c1e), never pure black.
*   **The "Ghost Border":** If accessibility requires a border (e.g., in high-contrast needs), use the `outline-variant` (#c2c6d4) at 20% opacity. It should be felt, not seen.

## 5. Components & Interface Patterns

### Buttons (The Interaction Pillars)
*   **Primary:** Gradient of `primary` to `primary-container`. Border radius: `md` (0.75rem). No shadow, but a slight 2px vertical "lift" on hover.
*   **Tertiary (Lesson Controls):** Use `on-surface-variant` text with no background. On hover, apply a `surface-container-highest` background with 0.5s ease-in-out.

### Input Fields (The Writing Desk)
*   Forbid "box" style inputs. Use a "Minimalist Ledger" style: a `surface-container-low` background with a slightly thicker bottom-border of `outline-variant` that transforms to `primary` on focus.

### Cards & Lists (Content Containers)
*   **The Divider Ban:** Strictly forbid 1px horizontal dividers between list items. Use **Vertical White Space** (scale: `1.5rem`) to separate concepts.
*   **Success States:** When a translation is correct, transition the container background to `tertiary-fixed` (#6ffbbe) at 10% opacity. Do not use heavy green backgrounds; use a "wash" of color.

### Progress Indicators (Subtle Mastery)
*   Instead of chunky bars, use a 2px "Filament" line using `tertiary`. It should feel like a fine thread running through the top of the interface.

## 6. Do's and Don'ts

### Do:
*   **Do** use asymmetrical padding. Give the "Foreign Language" text more leading and tracking than the UI labels to emphasize its importance.
*   **Do** use `rounded-lg` (1rem) for large containers and `rounded-md` (0.75rem) for interactive elements like buttons.
*   **Do** leverage Lucide icons with a `1.5px` stroke weight. Icons should be `on-surface-variant` color to remain secondary to text.

### Don't:
*   **Don't** use "Alert Red" for errors unless critical. Use `error-container` (#ffdad6) with `on-error-container` text for a softer, more encouraging correction.
*   **Don't** use pure black (#000) for text. Use `on-surface` (#191c1e) to maintain the editorial, paper-like softness.
*   **Don't** use standard "Center-Aligned" layouts for everything. Use "Left-Flush" editorial layouts with wide right-hand margins for notes and metadata.

## 7. Roundedness Scale
*   **Small (`sm`):** 0.25rem (Small tooltips)
*   **Medium (`md`):** 0.75rem (Buttons, Inputs)
*   **Large (`lg`):** 1rem (Main content cards)
*   **Extra Large (`xl`):** 1.5rem (Hero sections, bottom sheets)
*   **Full:** 9999px (Pills, Chips)