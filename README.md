# dacort.dev

Personal site for [dacort.xyz](https://dacort.xyz), built with [Hugo](https://gohugo.io/) and the [PaperMod](https://github.com/adityatelange/hugo-PaperMod) theme.

## Local Development

```bash
cd site
hugo server -D
```

Visit http://localhost:1313

## Deep Thoughts by AI

"Deep Thoughts by AI" is a section where philosophical/humorous quotes each get a unique generative art experience — a self-contained HTML canvas piece with visuals, interaction, and ambient audio.

### Adding a new thought

1. **Add an entry to the data file** (`site/data/deep-thoughts.yaml`):

   ```yaml
   - id: "your-thought-id"
     text: "Your philosophical quote here."
     date: 2026-03-01
     mood: "wistful"
   ```

   The `id` becomes the URL slug. The `mood` is freeform — it guides the art generation and shows as a tag in the gallery.

2. **Generate the art piece:**

   ```bash
   ./generate-deep-thought.sh your-thought-id
   ```

   This creates a Hugo page bundle at `site/content/deep-thoughts-by-ai/your-thought-id/` with:
   - `index.md` — frontmatter pulled from the YAML entry
   - `thought.html` — a bespoke generative art piece created by Claude Code

   **Requires:** [yq](https://github.com/mikefarah/yq) and [Claude Code](https://docs.anthropic.com/en/docs/claude-code)

3. **Preview locally:**

   ```bash
   cd site && hugo server -D
   ```

   - Gallery: http://localhost:1313/deep-thoughts-by-ai/
   - New thought: http://localhost:1313/deep-thoughts-by-ai/your-thought-id/

4. **Commit and push** when you're happy with it.

### How it works

Each thought is a Hugo page bundle with a standalone layout that bypasses PaperMod's chrome. The `thought.html` art piece is embedded via `srcdoc` iframe with a click-to-enter overlay. The art pieces are self-contained (no external deps) with canvas animation, mouse/touch interaction, and Web Audio API ambient sound.
