# Offcanvas Extension For Quarto

This Quarto extension provides a simple way to create Bootstrap 5 offcanvas components in your HTML documents.

Offcanvas components are sliding panels that can be triggered from buttons and appear from any edge of the viewport.

## Installation

```bash
quarto add mcanouil/quarto-offcanvas@1.1.0
```

This will install the extension under the `_extensions` subdirectory.

If you're using version control, you will want to check in this directory.

## Usage

To use offcanvas in your HTML Quarto document, you need to include the `offcanvas` extension in your YAML header.

```yaml
filters:
  - path: offcanvas
    at: pre-quarto
```

Create an offcanvas component using a fenced div with the `.offcanvas` class:

```markdown
:::: {.offcanvas}

# Offcanvas Title

Your content goes here.

:::
```

### Basic Configuration

Customise the offcanvas behaviour with attributes:

```markdown
:::: {.offcanvas placement="end" width="450px" trigger-text="Settings"}

# Settings Panel

Configure your preferences here.

:::
```

### Available Attributes

| Attribute          | Type           | Default             | Description                                                                                       |
| ------------------ | -------------- | ------------------- | ------------------------------------------------------------------------------------------------- |
| `placement`        | string         | `"start"`           | Position: `"start"`, `"end"`, `"top"`, `"bottom"` (also accepts `"left"`, `"right"`)[^1]          |
| `width`            | string         | `"400px"`           | Width for start/end placement                                                                     |
| `height`           | string         | `"30vh"`            | Height for top/bottom placement                                                                   |
| `backdrop`         | string/boolean | `"true"`            | `"true"`, `"false"`, or `"static"`                                                                |
| `scroll`           | boolean        | `"false"`           | Allow body scrolling when open                                                                    |
| `keyboard`         | boolean        | `"true"`            | Close with Escape key                                                                             |
| `trigger-text`     | string         | `"Open"`            | Text for trigger button                                                                           |
| `trigger-class`    | string         | `"btn btn-primary"` | CSS classes for trigger button (use `"none"` or `""` for no classes)                              |
| `trigger-icon`     | string         | `""`                | Icon class (*e.g.*, Bootstrap Icons)                                                              |
| `trigger-position` | string         | `"inline"`          | `"inline"` or `"none"` (no auto trigger)                                                          |
| `trigger-type`     | string         | `"button"`          | Type of trigger element: `"button"` or `"text"` (span element)                                    |
| `title`            | string         | auto-extracted      | Override title from first heading                                                                 |
| `show-close`       | boolean        | `"true"`            | Show close button in header                                                                       |
| `responsive`       | string         | `""`                | Responsive breakpoint: `"sm"`, `"md"`, `"lg"`, `"xl"`, `"xxl"` (hides offcanvas below breakpoint) |
| `overtake-margins` | boolean        | `"false"`           | Convert Quarto margin content to offcanvas                                                        |

For more information about Bootstrap offcanvas components, see the [official Bootstrap documentation](https://getbootstrap.com/docs/5.3/components/offcanvas/).

[^1]: `"left"` is an alias for `"start"` and `"right"` is an alias for `"end"`.

### Margin Overtake Feature

The extension can automatically convert Quarto margin content (elements with `.column-margin` or `.aside` classes) into offcanvas components.

This is particularly useful for making margin notes accessible on mobile devices while not cluttering the main content area.

To enable this feature:

```yaml
---
format: html
extensions:
  offcanvas:
    overtake-margins: true
    placement: end
    width: 450px
    trigger-class: btn btn-sm btn-outline-secondary
---
```

When enabled, all margin content will be converted to offcanvas panels with trigger buttons placed in the margin.

The trigger button text is automatically extracted from the first 30 characters of the margin content, unless overridden with the `trigger-text` attribute.

You can customise individual margin elements using attributes:

```markdown
:::: {.column-margin trigger-text="View details" title="Additional Info"}
Content here.
:::
```

All standard offcanvas attributes are supported on margin elements (placement, width, height, backdrop, scroll, keyboard, trigger-class, trigger-icon, title, show-close).

### Document-wide Configuration

Set default values for all offcanvas components in the document metadata:

```yaml
---
title: "My Document"
format: html
extensions:
  offcanvas:
    placement: end
    width: 450px
    trigger-class: btn btn-outline-secondary
---
```

### Examples

#### Navigation Menu

```markdown
:::: {.offcanvas placement="start" trigger-text="Menu" trigger-icon="bi bi-list"}

# Navigation

- [Home](#home)
- [About](#about)
- [Contact](#contact)

:::
```

#### Settings Panel

```markdown
:::: {.offcanvas placement="end" width="350px" trigger-text="Settings"}

# Preferences

- [ ] Dark mode
- [ ] Notifications
- [ ] Auto-save

:::
```

#### Top Notification Bar

```markdown
:::: {.offcanvas placement="top" height="200px" backdrop="false" scroll="true"}

# Announcements

Important system notice.

:::
```

#### Offcanvas with Footer

Use a horizontal rule to separate body and footer:

```markdown
:::: {.offcanvas placement="end" trigger-text="Details"}

# Details

Main content here.

---

**Footer Section**

[Save](#){.btn .btn-primary}
[Cancel](#){.btn .btn-secondary bs-dismiss="offcanvas"}

:::
```

#### Custom Trigger with Manual Control

Set `trigger-position="none"` to manage the trigger yourself:

```markdown
:::: {#my-custom-offcanvas .offcanvas trigger-position="none"}

# Custom Offcanvas

This offcanvas has no automatic trigger.

You control when and how to open it.

:::

[Open Custom Offcanvas](#my-custom-offcanvas){bs-toggle="offcanvas"}
```

This allows you to create custom trigger elements anywhere in your document using the syntax:

```markdown
[Link Text](#offcanvas-id){bs-toggle="offcanvas"}
```

#### Text Trigger (No Button Styling)

Use `trigger-type="text"` for a plain text trigger instead of a button:

```markdown
:::: {.offcanvas trigger-type="text" trigger-text="Click here" trigger-class="text-primary"}

# Text Trigger Example

This offcanvas is triggered by plain text instead of a button.

:::
```

#### Trigger Without CSS Classes

Use `trigger-class="none"` or `trigger-class=""` to remove all CSS classes:

```markdown
:::: {.offcanvas trigger-class="none" trigger-text="Plain Trigger"}

# No Styling

This trigger has no CSS classes applied.

:::
```

#### Placement Aliases

Use `"left"` and `"right"` as convenient aliases:

```markdown
:::: {.offcanvas placement="left"}

# Left Panel

This is equivalent to `placement="start"`.

:::
```

```markdown
:::: {.offcanvas placement="right"}

# Right Panel

This is equivalent to `placement="end"`.

:::
```

## Example

Here is the source code for a comprehensive example: [example.qmd](example.qmd).

Outputs of `example.qmd`:

- [HTML](https://m.canouil.dev/quarto-offcanvas/)
