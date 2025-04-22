# Copy Context AI for Godot

**A Godot Editor plugin to easily copy project context (file structure, code) for AI assistants and apply modification commands received from them.**

[![Godot Version](https://img.shields.io/badge/Godot-4.x-blue?logo=godotengine)](https://godotengine.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE) <!-- Adjust if your license is different -->

It's useful for getting AI help to refactor code, generate boilerplate, create new scenes/scripts, or perform other project changes. The plugin allows you to easily provide relevant project context to an AI and execute its suggested modification commands via a simple copy-paste workflow.

## How to Install this Plugin?

1.  Paste the `copy_context_ai` folder into the `addons` folder in your Godot project (create an `addons` folder if you don't have one).
2.  Go to "Project" -> "Project Settings" -> "Plugins" tab.
3.  Find "CopyContextAI" (or similar name) in the list and set its status to "Enabled".

## Description

This plugin streamlines the interaction between Godot developers and AI coding assistants (like ChatGPT, Claude, Gemini, etc.). It provides a dockable panel within the Godot editor that allows you to:

1.  **Select Project Context:** Choose specific files and folders from your project structure to include.
2.  **Copy Context for AI:** Generate a structured XML (`<GodotContextOutput>`) containing the file tree and the content of selected files, ready to be pasted into your AI chat.
3.  **Include System Prompt:** Optionally prepend a detailed system prompt that instructs the AI on how to interpret the context and generate modification commands.
4.  **Paste AI Commands:** Paste XML commands (`<GodotContextCommand>`) received from the AI directly into the plugin.
5.  **Apply Modifications:** Execute the AI's commands to create, replace, patch, delete, or rename files within your project safely.

It aims to reduce the tedious manual work of copying/pasting code and instructions, making AI-assisted development faster and less error-prone.

## Features

*   **Dockable File Tree:** Visual representation of your `res://` directory within the Godot editor.
*   **Tri-State Checkboxes:**
    *   `[ ]` (Unchecked): Exclude this item from the detailed context.
    *   `[x]` (Checked): Include the full content of this file in the context.
    *   `[-]` (Indeterminate): Include a summary (first few lines) of this file, or indicate a partially included folder.
*   **Context Copying:**
    *   `Copy context` button generates the `<GodotContextOutput>` XML for the AI.
    *   `Sys` checkbox: If checked, prepends the content of `addons/copy_context_ai/scripts/copy_sysprompt_content.md` to the clipboard *before* the XML context. *Note: The checkbox automatically unchecks after copying.*
    *   `Ctrl+C` / `Cmd+C` shortcut when the plugin panel has focus.
*   **Command Pasting & Execution:**
    *   `Paste request` button takes `<GodotContextCommand>` XML from the clipboard and attempts to execute the file modifications.
    *   `Ctrl+V` / `Cmd+V` shortcut when the plugin panel has focus.
*   **Supported Operations:** Create Files, Replace Files (overwrite), Patch Files (find/replace blocks), Delete Files/Folders, Rename Files/Folders.
*   **Context Update:** Processes `<SetContext>` commands from the AI to automatically update the file tree checkboxes after modifications.
*   **Filesystem Navigation:** Right-click an item in the tree to navigate to it in Godot's main FileSystem dock.
*   **Character Limit:** Prevents generating excessively large context outputs (configurable limit, currently ~700k characters).

## Motivation

Interacting with AI assistants for coding often requires providing significant context about the project. Manually copying file structures and relevant code snippets is time-consuming and error-prone. Furthermore, applying the AI's suggestions back into the project involves careful manual editing. This plugin automates both sides of this workflow.

## Installation

1.  **Download/Clone:** Obtain the plugin files. You can either:
    *   Download the repository ZIP and extract it.
    *   Clone the repository using Git: `git clone <repository_url>`.
2.  **Place in Project:** Copy the `copy_context_ai` folder into your Godot project's `addons/` directory. Create the `addons` folder if it doesn't exist. The final path should be `res://addons/copy_context_ai/`.
3.  **Enable Plugin:** Go to `Project` -> `Project Settings` -> `Plugins` tab. Find "CopyContextAI" in the list and check the `Enable` box.
4.  **Restart Editor (Recommended):** Sometimes necessary for the dock panel to appear correctly.

## Usage

1.  **Access the Plugin:** After enabling, find the "CopyContextAI" panel in one of the editor docks (usually defaults to Left-Bottom, alongside FileSystem, History, etc.).
2.  **Select Context:**
    *   The file tree shows your `res://` directory.
    *   Click the checkbox next to files or folders to cycle their state:
        *   `[ ]` -> `[x]` -> `[-]` -> `[ ]`
    *   Use `[x]` for files the AI needs full access to modify or understand completely.
    *   Use `[-]` for files where a summary is sufficient, or for folders where you only include some children.
    *   Use `[ ]` to exclude items entirely. Folders automatically update their state based on their children.
3.  **Copy Context:**
    *   Decide if you want to include the system prompt (recommended for the first interaction with the AI). Check the `Sys` box if desired.
    *   Click the `Copy context` button (or use `Ctrl+C`/`Cmd+C`).
    *   Paste the content into your AI assistant's chat interface.
4.  **Receive and Paste Commands:**
    *   The AI *should* respond with an explanation of its plan, followed *only* by a `<GodotContextCommand>...</GodotContextCommand>` XML block (as instructed by the default system prompt).
    *   Copy the *entire* XML block provided by the AI.
    *   Click the `Paste request` button in the plugin (or use `Ctrl+V`/`Cmd+V`).
5.  **Review and Apply:**
    *   The plugin will parse the XML and attempt to perform the requested file operations. Check Godot's Output panel for success messages, warnings, or errors.
    *   If the command included `<SetContext>`, the file tree checkboxes will update automatically to reflect the changes (e.g., marking created files as `[x]`).
    *   If modifications were made, the file tree might refresh.
6.  **Iterate:** Repeat steps 2-5 for further modifications. You might not need the `Sys` checkbox on subsequent requests if the AI retains the instructions.

## Understanding the Formats

*   **`<GodotContextOutput>`:** Contains the `<FileStructure>` (text tree) and `<FileDetails>` (content of `[x]` and `[-]` files) you send to the AI. See `addons/copy_context_ai/scripts/copy_context_example.xml`.
*   **`<GodotContextCommand>`:** Contains instructions for the plugin (`<ModifyFiles>` with operations like `<ReplaceFiles>`, `<CreateFiles>`, `<PatchFiles>`, etc., and optionally `<SetContext>`). See `addons/copy_context_ai/scripts/paste_request_example.xml`.

## System Prompt (`copy_sysprompt_content.md`)

*   Located at: `res://addons/copy_context_ai/scripts/copy_sysprompt_content.md`
*   **Purpose:** This crucial file tells the AI how to behave. It explains the `GodotContextOutput` format it receives and the `GodotContextCommand` format it *must* generate.
*   **Customization:** You can edit this file to tailor the AI's behavior, constraints, or persona. However, ensure you don't break the core instructions regarding the XML formats.

## Limitations & Caveats

*   **Experimental:** This plugin modifies your project files. **Always use version control (like Git) and back up your project before applying commands.**
*   **Patch Fragility:** The `<PatchFiles>` operation requires the `<<<<<<< SEARCH` block to match the existing file content *exactly* (including whitespace and line endings). If the file has changed since the context was copied, or if the AI doesn't generate the `SEARCH` block perfectly, the patch will fail. Providing full context (`[x]`) for files you intend to patch is recommended.
*   **No Deep Validation:** The plugin performs basic XML parsing but doesn't deeply validate the *logic* of the AI's commands before executing them. Review the AI's plan carefully.
*   **Character Limit:** Very large projects or files might exceed the context character limit, causing truncation. The plugin attempts to handle this gracefully, but be aware that the AI might not receive the full picture.
*   **Error Handling:** File operation errors are logged to the Godot Output panel. The plugin tries to continue but might leave the project in an inconsistent state if multiple operations fail.

## Contributing

Contributions (bug reports, feature requests, pull requests) are welcome! Please open an issue or PR on the repository page.

## License

This plugin is distributed under the MIT License. See the `LICENSE` file for more details. (If you haven't added one, consider adding a simple `LICENSE` file with the MIT text).

## Author

*   **@EliasGuyd**