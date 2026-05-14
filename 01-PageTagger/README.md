# 🏷️ Smart Tagger for Xournal++
*Transform Xournal++ into an immersive learning, tagging, and review engine.*

[🇨🇳 中文文档 (Chinese README)](README_zh.md)

Smart Tagger is an advanced, highly customized plugin for Xournal++. Built for students, researchers, and professionals, it turns your PDF reading experience into a "Document OS". It breaks the limits of native APIs to introduce virtual chapters, X-Ray vision review, zero-friction clipboard navigation, and a stateless local database.

## ✨ Core Features

* 👁️ **X-Ray Vision Engine**: During review mode, hidden notes and tags **automatically fade in** the moment you jump to a page, and instantly vanish like ghosts when you switch to the next page, ensuring a distraction-free flow state.
* ⛳ **Virtual Chapters**: Using a special `@chapter` anchor, you can dynamically build a table of contents for PDFs that lack native bookmarks. It supports looping reviews *strictly* within the current chapter boundaries.
* 🚀 **Zero-Friction Search**: No clunky search boxes! See a word you want to review? Highlight it, cut it (`Ctrl+X`), and hit the browse shortcut to instantly teleport to its tagged pages. 
* 🗄️ **Stateless Document DB**: Automatically creates a hidden `@metadata` layer on page 1. Your custom tags and color palettes are saved in standard INI format **inside the PDF itself**. Your configurations travel with your document!
* 🎨 **Dynamic SVG Toolbar**: Reads your database configuration, auto-generates custom-colored SVG icons in the background, and seamlessly injects them into the native Xournal++ toolbar.

---

## 🛠️ Installation

1. Locate your Xournal++ plugins directory:
   * **Windows**: Type `%LOCALAPPDATA%\xournalpp\plugins\` in your File Explorer.
   * **macOS / Linux**: Usually `~/.local/share/xournalpp/plugins/` or `~/.xournalpp/plugins/`.
2. Create a new folder named `Tagger` inside the `plugins` directory.
3. Drop all the `.lua` files from this repository into the `Tagger` folder.
4. Open Xournal++, go to `Plugin` -> `Plugin Manager`, and enable **Tagger**.
5. **Fully restart Xournal++** for the plugin to take effect.

---

## 🚀 Day 1 Experience: Customizing Your Toolbar

By default, the plugin provides 6 built-in tags (`core`, `hard`, `insight`, `code`, `todo`, `skip`). Here is how to customize them for specific subjects (e.g., Mathematics, Languages):

1. Type 6 tags separated by commas anywhere (e.g., `math, physics, chem, bio, geo, hist, eng`).
2. Select and copy (`Ctrl+C`) or cut (`Ctrl+X`) them.
3. Go back to Xournal++ and press **`Alt+X`** (Setup & Sync Icons).
4. The plugin will write these tags into the PDF's hidden database and generate 6 custom SVG icons in the background.
5. **Restart Xournal++** to see your brand-new, customized toolbar!

*(🎨 **Pro Theme Tip**: If you want to change button colors, copy 6 HEX color codes like `#FF0000, #00FF00...` and press `Alt+X` to apply a new color theme to the document!)*

---

## ⌨️ Keybindings & Workflows

All core actions are bound to global shortcuts to keep your hands on the keyboard.

| Shortcut | Action | Description |
| :--- | :--- | :--- |
| **`Alt+A`** | 📝 **Add Tag w/ Note** | Copy text formatted as `tag: note`, press this shortcut to apply the tag and leave a hidden red note. |
| **`Alt+D`** | 🗑️ **Delete Tag** | Opens a dialog to safely remove a specific tag from the current page. |
| **`Alt+F`** | 🌍 **Browse Global** | Prompts you to select a tag, then teleports you through all pages containing that tag in the entire book. |
| **`Alt+C`** | 📖 **Browse Chapter** | Same as above, but loops **strictly within the current chapter** (between `@chapter` anchors). |
| **`Alt+V`** | 🔤 **Add Vocab** | Select a word, copy it, and press this to silently add it to a dedicated blue vocabulary layer in the top right corner. |
| **`Alt+X`** | 🔄 **Setup & Sync** | Reads your clipboard to update the database tags or colors, and regenerates toolbar icons. |
| **`N/A`** | ⚡ **Quick Tag** | Opens a menu to quickly apply one of your 6 database tags to the current page. |
| **`N/A`** | 📊 **Generate Summary** | Extracts all tags and notes from the entire book and generates a formatted, chapter-grouped table of contents on the canvas. |
| **`N/A`** | 🧹 **Sanitize Workspace**| Hides all `tag_` layers and restores your workspace to a clean state if you accidentally reveal hidden layers. |

---

## 💡 The Pro Workflows

**1. How to drop Chapter Anchors?**
When you start a new chapter, highlight the title (e.g., "Chapter 3: Calculus"), press `Ctrl+C` (Copy), and click the `[chapter]` button on your toolbar. Confirm the prompt, and a system badge will appear, marking the boundary for chapter-based reviews.

**2. Zero-Friction Teleportation**
You don't need to navigate menus to start a review session. Simply highlight a tag word on your screen (like `core`), press `Ctrl+X` to cut it, and hit **`Alt+F`**. The plugin will instantly teleport you to the first page with a `core` tag!

**3. The "Burn-After-Reading" Flow**
When using the X-Ray review mode, **do not use your mouse wheel to scroll!**
Read the automatically revealed red notes on the current page, and when you are done, press `Alt+F` (or `C`) again to jump to the next tagged page. The plugin will automatically clean up and hide the notes on the page you just left.

---

## 🏗️ Architecture Notes

* **Everything is a Layer**: Tags, chapter anchors, and even the local database are physically stored as standard text objects inside hidden layers. No external files are required. If you share your PDF with another user who has this plugin, all configurations and review states travel with the file.
* **INI over `@metadata`**: The database uses a strict INI format with namespace isolation. Tagger saves data under the `[Tagger]` block, ensuring future compatibility and allowing other plugins to share the same `@metadata` layer without conflict.
