--- @module "offcanvas"
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil

--- Extension name constant
local EXTENSION_NAME = 'offcanvas'

--- Constants for trigger text extraction
local MAX_TEXT_EXTRACT = 50
local MAX_TRIGGER_LENGTH = 30
local TRUNCATE_LENGTH = 27

--- Bootstrap compatibility
--- The extension targets Bootstrap 5 (5.0+); offcanvas is unavailable in Bootstrap 4 or earlier.
--- The responsive `.offcanvas-{sm,md,lg,xl,xxl}` variants require Bootstrap 5.2 or later.
--- See the README for the full compatibility statement.

--- Valid placement and responsive values (hash tables for O(1) lookup)
local VALID_PLACEMENTS = { start = true, ['end'] = true, top = true, bottom = true }
local VALID_RESPONSIVE = { sm = true, md = true, lg = true, xl = true, xxl = true }
local VALID_TRIGGER_POSITIONS = { inline = true, none = true }
local VALID_TRIGGER_TYPES = { button = true, text = true }
local VALID_BACKDROPS = { ['true'] = true, ['false'] = true, static = true }

--- Animation preset definitions (CSS transition duration in milliseconds).
local ANIMATION_PRESETS = {
  none = '0ms',
  fast = '150ms',
  normal = '300ms',
  slow = '500ms'
}

--- Load required modules
local str = require(quarto.utils.resolve_path('_modules/string.lua'):gsub('%.lua$', ''))
local log = require(quarto.utils.resolve_path('_modules/logging.lua'):gsub('%.lua$', ''))
local meta_mod = require(quarto.utils.resolve_path('_modules/metadata.lua'):gsub('%.lua$', ''))
local pdoc = require(quarto.utils.resolve_path('_modules/pandoc-helpers.lua'):gsub('%.lua$', ''))
local html_mod = require(quarto.utils.resolve_path('_modules/html.lua'):gsub('%.lua$', ''))
local content = require(quarto.utils.resolve_path('_modules/content-extraction.lua'):gsub('%.lua$', ''))

--- Counter for unique offcanvas IDs (reset per document in the Meta pass).
local offcanvas_count = 0

--- Track whether the JS helper dependency has been added (reset per document in the Meta pass).
local js_helper_added = false

--- Generate unique offcanvas ID
--- @return string Unique ID for offcanvas element
local function unique_offcanvas_id()
  offcanvas_count = offcanvas_count + 1
  return 'oc-' .. tostring(offcanvas_count)
end

-- ============================================================================
-- OFFCANVAS SETTINGS
-- ============================================================================

--- Offcanvas settings default values
--- @type table<string, string>
local offcanvas_settings_defaults = {
  placement = 'start',
  width = '400px',
  height = '30vh',
  backdrop = 'true',
  scroll = 'false',
  keyboard = 'true',
  ['trigger-text'] = 'Open',
  ['trigger-class'] = 'btn btn-primary',
  ['trigger-icon'] = '',
  ['trigger-position'] = 'inline',
  ['trigger-type'] = 'button',
  ['trigger-style'] = '',
  ['show-close'] = 'true',
  responsive = '',
  ['overtake-margins'] = 'false',
  animation = '',
  ['auto-dismiss'] = ''
}

--- Resolved offcanvas settings for the current document (populated in the Meta pass).
--- @type table<string, string>
local offcanvas_settings = {}

--- Get offcanvas option from metadata
--- @param key string The option name to retrieve
--- @param meta table Document metadata table
--- @return string The option value as a string
local function get_offcanvas_option(key, meta)
  local meta_value = meta_mod.get_metadata_value(meta, 'offcanvas', key)
  if not str.is_empty(meta_value) then
    return meta_value
  end

  return offcanvas_settings_defaults[key] or ''
end

--- Reset per-document state and load settings from document metadata.
--- @param meta table Document metadata table
--- @return table Updated metadata table with offcanvas configuration
local function get_offcanvas_meta(meta)
  offcanvas_count = 0
  js_helper_added = false

  for key, _ in pairs(offcanvas_settings_defaults) do
    offcanvas_settings[key] = get_offcanvas_option(key, meta)
  end

  meta['extensions'] = meta['extensions'] or {}
  meta['extensions']['offcanvas'] = meta['extensions']['offcanvas'] or {}
  for key, value in pairs(offcanvas_settings) do
    meta['extensions']['offcanvas'][key] = value
  end

  return meta
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Escape HTML special characters to prevent attribute injection.
--- @param value string|nil String to escape
--- @return string Escaped string safe for HTML
local function escape_html(value)
  if not value or value == '' then
    return ''
  end

  local escape_chars = {
    ['&'] = '&amp;',
    ['<'] = '&lt;',
    ['>'] = '&gt;',
    ['"'] = '&quot;',
    ["'"] = '&#39;'
  }

  return (value:gsub('[&<>"\']', escape_chars))
end

--- Normalise placement aliases to Bootstrap standard values
--- @param placement string Placement value (may be alias like 'left' or 'right')
--- @return string Normalised placement ('start', 'end', 'top', or 'bottom')
local function normalise_placement(placement)
  if placement == 'left' then
    return 'start'
  elseif placement == 'right' then
    return 'end'
  else
    return placement
  end
end

--- Configure Bootstrap data attributes for offcanvas behaviour
--- @param backdrop string Backdrop setting ('true', 'false', or 'static')
--- @param scroll string Scroll setting ('true' or 'false')
--- @param keyboard string Keyboard setting ('true' or 'false')
--- @return table Table of Bootstrap data attributes
local function configure_bootstrap_attrs(backdrop, scroll, keyboard)
  local attrs = {}

  if backdrop == 'static' then
    attrs['data-bs-backdrop'] = 'static'
  elseif backdrop == 'false' then
    attrs['data-bs-backdrop'] = 'false'
  end

  if scroll == 'true' then
    attrs['data-bs-scroll'] = 'true'
  end

  if keyboard == 'false' then
    attrs['data-bs-keyboard'] = 'false'
  end

  return attrs
end

--- Parse and validate the auto-dismiss timeout value (milliseconds).
--- @param value string Auto-dismiss value (positive integer in ms)
--- @return integer|nil Validated timeout, or nil if not set or invalid
local function parse_auto_dismiss(value)
  if not value or value == '' then
    return nil
  end

  local timeout = tonumber(value)
  if not timeout or timeout <= 0 or timeout ~= math.floor(timeout) then
    log.log_warning(EXTENSION_NAME,
      'Invalid auto-dismiss value "' .. value .. '". Expected a positive integer (milliseconds). Ignoring.')
    return nil
  end

  return timeout
end

--- Resolve the animation preset to a CSS transition duration.
--- @param value string Animation preset name or empty
--- @return string|nil Resolved CSS duration, or nil if no animation requested
local function resolve_animation(value)
  if not value or value == '' then
    return nil
  end

  local duration = ANIMATION_PRESETS[value]
  if not duration then
    log.log_warning(EXTENSION_NAME,
      'Invalid animation preset "' .. value .. '". Expected one of: none, fast, normal, slow. Ignoring.')
    return nil
  end

  return duration
end

--- Merge a user-supplied inline style with an extension-supplied one, preserving both.
--- @param user_style string|nil User-provided style (already trimmed)
--- @param extra_style string|nil Extension-provided style fragment
--- @return string|nil Combined style string, or nil if both are empty
local function merge_inline_styles(user_style, extra_style)
  local parts = {}

  if user_style and user_style ~= '' then
    local trimmed = user_style:match('^%s*(.-)%s*$')
    if trimmed ~= '' then
      if not trimmed:match(';%s*$') then
        trimmed = trimmed .. ';'
      end
      table.insert(parts, trimmed)
    end
  end

  if extra_style and extra_style ~= '' then
    table.insert(parts, extra_style)
  end

  if #parts == 0 then
    return nil
  end

  return table.concat(parts, ' ')
end

--- Ensure the JS helper script is registered when needed.
local function ensure_js_helper()
  if js_helper_added then
    return
  end
  js_helper_added = true
  html_mod.ensure_html_dependency({
    name = 'quarto-offcanvas-js',
    version = '1.0.0',
    scripts = { 'offcanvas.js' }
  })
end

--- Validate shared offcanvas options and resolve derived behaviours.
--- Warns and coerces invalid `backdrop` and `trigger_type` values, resolves the
--- animation preset and auto-dismiss timeout, and registers the JS helper when
--- an auto-dismiss timeout is set.
--- @param opts table Mutable options table with `backdrop`, `trigger_type`, `animation`, `auto_dismiss` keys
--- @return string|nil animation_duration, integer|nil auto_dismiss_ms
local function validate_and_resolve_options(opts)
  if not VALID_BACKDROPS[opts.backdrop] then
    log.log_warning(EXTENSION_NAME,
      'Invalid backdrop "' .. opts.backdrop .. '". Expected "true", "false", or "static". Using "true".')
    opts.backdrop = 'true'
  end

  if not VALID_TRIGGER_TYPES[opts.trigger_type] then
    log.log_warning(EXTENSION_NAME,
      'Invalid trigger-type "' .. opts.trigger_type .. '". Expected "button" or "text". Using "button".')
    opts.trigger_type = 'button'
  end

  local animation_duration = resolve_animation(opts.animation)
  local auto_dismiss_ms = parse_auto_dismiss(opts.auto_dismiss)

  if auto_dismiss_ms then
    ensure_js_helper()
  end

  return animation_duration, auto_dismiss_ms
end

-- ============================================================================
-- OFFCANVAS STRUCTURE GENERATION
-- ============================================================================

--- Extract a custom trigger template from the offcanvas content blocks.
--- A child Div with class `offcanvas-trigger` is treated as a user-supplied
--- trigger template and removed from the body content.
--- @param blocks table Pandoc block list
--- @return table Remaining blocks, pandoc.Div|nil Template block (or nil)
local function extract_trigger_template(blocks)
  local remaining = {}
  local template = nil

  for _, block in ipairs(blocks) do
    if not template and block.t == 'Div' and pdoc.has_class(block.classes, 'offcanvas-trigger') then
      template = block
    else
      table.insert(remaining, block)
    end
  end

  return remaining, template
end

--- Generate complete offcanvas structure with optional trigger
--- @param config table Configuration object with offcanvas settings
--- @return pandoc.Div Offcanvas Div structure
local function generate_offcanvas_structure(config)
  local offcanvas_id = config.offcanvas_id
  local placement = config.placement
  local width = config.width
  local height = config.height
  local responsive = config.responsive
  local header_text = config.header_text
  local body_blocks = config.body_blocks
  local footer_blocks = config.footer_blocks
  local show_close = config.show_close
  local backdrop = config.backdrop
  local scroll = config.scroll
  local keyboard = config.keyboard
  local animation_duration = config.animation_duration
  local auto_dismiss_ms = config.auto_dismiss_ms

  local offcanvas_classes = { 'offcanvas', 'offcanvas-' .. placement }

  if responsive and responsive ~= '' then
    if VALID_RESPONSIVE[responsive] then
      table.insert(offcanvas_classes, 'offcanvas-' .. responsive)
    else
      log.log_warning(EXTENSION_NAME, 'Invalid responsive breakpoint "' .. responsive .. '". Ignoring.')
    end
  end

  local offcanvas_attrs = {
    tabindex = '-1',
    ['aria-labelledby'] = offcanvas_id .. '-label'
  }

  local bootstrap_attrs = configure_bootstrap_attrs(backdrop, scroll, keyboard)
  for key, value in pairs(bootstrap_attrs) do
    offcanvas_attrs[key] = value
  end

  if auto_dismiss_ms then
    offcanvas_attrs['data-offcanvas-auto-dismiss'] = tostring(auto_dismiss_ms)
  end

  local header_blocks = {}
  if header_text then
    local header_html = '<h5 class="offcanvas-title" id="' .. escape_html(offcanvas_id) .. '-label">' ..
        escape_html(header_text) .. '</h5>'
    table.insert(header_blocks, pandoc.RawBlock('html', header_html))
  end

  if show_close == 'true' then
    table.insert(header_blocks,
      pandoc.RawBlock('html',
        '<button type="button" class="btn-close" data-bs-dismiss="offcanvas" aria-label="Close"></button>')
    )
  end

  local offcanvas_header = pandoc.Div(header_blocks, pdoc.attr('', { 'offcanvas-header' }))

  local offcanvas_body = pandoc.Div(body_blocks, pdoc.attr('', { 'offcanvas-body' }))

  local offcanvas_content = { offcanvas_header, offcanvas_body }

  if footer_blocks and #footer_blocks > 0 then
    local offcanvas_footer = pandoc.Div(footer_blocks, pdoc.attr('', { 'offcanvas-footer' }))
    table.insert(offcanvas_content, offcanvas_footer)
  end

  local offcanvas_div = pandoc.Div(
    offcanvas_content,
    pdoc.attr(offcanvas_id, offcanvas_classes, offcanvas_attrs)
  )

  local size_style = nil
  if placement == 'start' or placement == 'end' then
    size_style = 'width: ' .. width .. ';'
  elseif placement == 'top' or placement == 'bottom' then
    size_style = 'height: ' .. height .. ';'
  end

  local animation_style = nil
  if animation_duration then
    animation_style = '--bs-offcanvas-transition-duration: ' .. animation_duration ..
        '; transition-duration: ' .. animation_duration .. ';'
  end

  local style_attr = merge_inline_styles(size_style, animation_style)
  if style_attr then
    offcanvas_div.attributes.style = style_attr
  end

  return offcanvas_div
end

-- ============================================================================
-- TRIGGER GENERATION
-- ============================================================================

--- Generate the trigger element wrapping the supplied inner HTML.
--- @param tag string HTML tag name ('button' or 'span')
--- @param offcanvas_id string ID of the offcanvas element
--- @param trigger_class string CSS classes for the element
--- @param trigger_style string User-supplied inline style (may be empty)
--- @param inner_html string Inner HTML content
--- @return string Trigger HTML
local function build_trigger_html(tag, offcanvas_id, trigger_class, trigger_style, inner_html)
  local escaped_id = escape_html(offcanvas_id)
  local escaped_class = escape_html(trigger_class)

  local class_attr = ''
  if trigger_class and trigger_class ~= 'none' and trigger_class ~= '' then
    class_attr = ' class="' .. escaped_class .. '"'
  end

  local extra_style = nil
  if tag == 'span' then
    extra_style = 'cursor: pointer;'
  end

  local merged_style = merge_inline_styles(trigger_style, extra_style)
  local style_attr = ''
  if merged_style then
    style_attr = ' style="' .. escape_html(merged_style) .. '"'
  end

  local type_attr = ''
  if tag == 'button' then
    type_attr = ' type="button"'
  end

  return '<' .. tag .. class_attr .. type_attr ..
      ' data-bs-toggle="offcanvas" data-bs-target="#' .. escaped_id .. '"' ..
      ' aria-controls="' .. escaped_id .. '"' .. style_attr .. '>' ..
      inner_html ..
      '</' .. tag .. '>'
end

--- Generate trigger HTML with text and optional icon.
--- @param offcanvas_id string ID of the offcanvas element
--- @param trigger_text string Button text
--- @param trigger_class string CSS classes for the button
--- @param trigger_icon string Icon class (optional)
--- @param trigger_type string Type of trigger ('button' or 'text')
--- @param trigger_style string User-supplied inline style (may be empty)
--- @return string HTML for trigger
local function generate_trigger(offcanvas_id, trigger_text, trigger_class, trigger_icon, trigger_type, trigger_style)
  local escaped_text = escape_html(trigger_text)
  local escaped_icon = escape_html(trigger_icon)

  local icon_html = ''
  if trigger_icon and trigger_icon ~= '' then
    icon_html = '<i class="' .. escaped_icon .. '"></i> '
  end

  local tag = trigger_type == 'text' and 'span' or 'button'
  return build_trigger_html(tag, offcanvas_id, trigger_class, trigger_style, icon_html .. escaped_text)
end

--- Generate a trigger from a user-supplied template Div.
--- The template Div's content becomes the inner HTML of the trigger element.
--- Single-paragraph templates are rendered as inlines so the trigger does not
--- contain a stray `<p>` wrapper.
--- @param offcanvas_id string ID of the offcanvas element
--- @param template_div pandoc.Div Template Div (class `offcanvas-trigger`)
--- @param trigger_class string CSS classes for the trigger element
--- @param trigger_type string Type of trigger ('button' or 'text')
--- @param trigger_style string User-supplied inline style (may be empty)
--- @return string HTML for trigger
local function generate_trigger_from_template(offcanvas_id, template_div, trigger_class, trigger_type, trigger_style)
  local rendered
  if #template_div.content == 1 and template_div.content[1].t == 'Para' then
    rendered = pandoc.write(pandoc.Pandoc({ pandoc.Plain(template_div.content[1].content) }), 'html')
  else
    rendered = pandoc.write(pandoc.Pandoc(template_div.content), 'html')
  end
  rendered = rendered:gsub('%s+$', '')
  local tag = trigger_type == 'text' and 'span' or 'button'
  return build_trigger_html(tag, offcanvas_id, trigger_class, trigger_style, rendered)
end

-- ============================================================================
-- OFFCANVAS FILTER
-- ============================================================================

--- Filter for Divs with class 'offcanvas'
--- @param el pandoc.Div Pandoc Div element
--- @return pandoc.Div|pandoc.Null Pandoc Div structure for offcanvas, or Null if not applicable
local function process_offcanvas(el)
  if not quarto.doc.is_format('html:js') or not quarto.doc.has_bootstrap() or not pdoc.has_class(el.classes, 'offcanvas') then
    return el
  end

  local offcanvas_id = el.identifier ~= '' and el.identifier or unique_offcanvas_id()

  local placement = el.attributes.placement or offcanvas_settings.placement
  local width = el.attributes.width or offcanvas_settings.width
  local height = el.attributes.height or offcanvas_settings.height
  local backdrop = el.attributes.backdrop or offcanvas_settings.backdrop
  local scroll = el.attributes.scroll or offcanvas_settings.scroll
  local keyboard = el.attributes.keyboard or offcanvas_settings.keyboard
  local trigger_text = el.attributes['trigger-text'] or offcanvas_settings['trigger-text']
  local trigger_class = el.attributes['trigger-class'] or offcanvas_settings['trigger-class']
  local trigger_icon = el.attributes['trigger-icon'] or offcanvas_settings['trigger-icon']
  local trigger_position = el.attributes['trigger-position'] or offcanvas_settings['trigger-position']
  local trigger_type = el.attributes['trigger-type'] or offcanvas_settings['trigger-type']
  local trigger_style = el.attributes['trigger-style'] or offcanvas_settings['trigger-style']
  local show_close = el.attributes['show-close'] or offcanvas_settings['show-close']
  local responsive = el.attributes.responsive or offcanvas_settings.responsive
  local animation = el.attributes.animation or offcanvas_settings.animation
  local auto_dismiss = el.attributes['auto-dismiss'] or offcanvas_settings['auto-dismiss']
  local title_override = el.attributes.title

  placement = normalise_placement(placement)

  if not VALID_PLACEMENTS[placement] then
    log.log_warning(EXTENSION_NAME, 'Invalid placement "' .. placement .. '". Using "start".')
    placement = 'start'
  end

  local opts = {
    backdrop = backdrop,
    trigger_type = trigger_type,
    animation = animation,
    auto_dismiss = auto_dismiss
  }
  local animation_duration, auto_dismiss_ms = validate_and_resolve_options(opts)
  backdrop = opts.backdrop
  trigger_type = opts.trigger_type

  local body_blocks_in, trigger_template = extract_trigger_template(el.content)
  local parsed = content.parse_sections(body_blocks_in)
  local header_text = title_override or parsed.header_text
  local body_blocks = parsed.body_blocks
  local footer_blocks = parsed.footer_blocks

  local protected_body = content.protect_headers(body_blocks, offcanvas_id)
  local protected_footer = #footer_blocks > 0 and content.protect_headers(footer_blocks, nil) or nil

  local offcanvas_div = generate_offcanvas_structure({
    offcanvas_id = offcanvas_id,
    placement = placement,
    width = width,
    height = height,
    responsive = responsive,
    header_text = header_text,
    body_blocks = protected_body,
    footer_blocks = protected_footer,
    show_close = show_close,
    backdrop = backdrop,
    scroll = scroll,
    keyboard = keyboard,
    animation_duration = animation_duration,
    auto_dismiss_ms = auto_dismiss_ms
  })

  if not VALID_TRIGGER_POSITIONS[trigger_position] then
    log.log_warning(EXTENSION_NAME, 'Invalid trigger-position "' .. trigger_position .. '". Using "inline".')
    trigger_position = 'inline'
  end

  if trigger_position == 'none' then
    return offcanvas_div
  end

  local trigger_html
  if trigger_template then
    trigger_html = generate_trigger_from_template(offcanvas_id, trigger_template, trigger_class, trigger_type,
      trigger_style)
  else
    trigger_html = generate_trigger(offcanvas_id, trigger_text, trigger_class, trigger_icon, trigger_type, trigger_style)
  end

  return pandoc.Div({
    pandoc.RawBlock('html', trigger_html),
    offcanvas_div
  })
end

-- ============================================================================
-- MARGIN OVERTAKE FUNCTIONALITY
-- ============================================================================

--- Convert Quarto margin content to offcanvas
--- @param el pandoc.Div|pandoc.Span Pandoc element
--- @return pandoc.Div|pandoc.Span Original or converted element
local function convert_margin_to_offcanvas(el)
  if offcanvas_settings['overtake-margins'] ~= 'true' then
    return el
  end

  if not quarto.doc.is_format('html:js') or not quarto.doc.has_bootstrap() then
    return el
  end

  local is_margin = pdoc.has_class(el.classes, 'column-margin') or
      pdoc.has_class(el.classes, 'aside') or
      pdoc.has_class(el.classes, 'margin')

  if not is_margin then
    return el
  end

  local offcanvas_id = el.identifier ~= '' and el.identifier or unique_offcanvas_id()

  local placement = el.attributes.placement or offcanvas_settings.placement
  local width = el.attributes.width or offcanvas_settings.width
  local height = el.attributes.height or offcanvas_settings.height
  local backdrop = el.attributes.backdrop or offcanvas_settings.backdrop
  local scroll = el.attributes.scroll or offcanvas_settings.scroll
  local keyboard = el.attributes.keyboard or offcanvas_settings.keyboard
  local trigger_class = el.attributes['trigger-class'] or offcanvas_settings['trigger-class']
  local trigger_icon = el.attributes['trigger-icon'] or offcanvas_settings['trigger-icon']
  local trigger_type = el.attributes['trigger-type'] or offcanvas_settings['trigger-type']
  local trigger_style = el.attributes['trigger-style'] or offcanvas_settings['trigger-style']
  local show_close = el.attributes['show-close'] or offcanvas_settings['show-close']
  local animation = el.attributes.animation or offcanvas_settings.animation
  local auto_dismiss = el.attributes['auto-dismiss'] or offcanvas_settings['auto-dismiss']
  local title_override = el.attributes.title

  placement = normalise_placement(placement)

  local opts = {
    backdrop = backdrop,
    trigger_type = trigger_type,
    animation = animation,
    auto_dismiss = auto_dismiss
  }
  local animation_duration, auto_dismiss_ms = validate_and_resolve_options(opts)
  backdrop = opts.backdrop
  trigger_type = opts.trigger_type

  local trigger_text = el.attributes['trigger-text']
  if not trigger_text or trigger_text == '' then
    trigger_text = 'View margin content'
    if el.content and #el.content > 0 then
      local first_text = str.stringify(el.content):sub(1, MAX_TEXT_EXTRACT)
      if first_text and first_text ~= '' then
        if #first_text > MAX_TRIGGER_LENGTH then
          trigger_text = first_text:sub(1, TRUNCATE_LENGTH) .. '...'
        else
          trigger_text = first_text
        end
      end
    end
  end

  local header_title = title_override or 'Margin Content'

  local offcanvas_div = generate_offcanvas_structure({
    offcanvas_id = offcanvas_id,
    placement = placement,
    width = width,
    height = height,
    responsive = '',
    header_text = header_title,
    body_blocks = el.content,
    footer_blocks = nil,
    show_close = show_close,
    backdrop = backdrop,
    scroll = scroll,
    keyboard = keyboard,
    animation_duration = animation_duration,
    auto_dismiss_ms = auto_dismiss_ms
  })

  local trigger_html = generate_trigger(offcanvas_id, trigger_text, trigger_class, trigger_icon, trigger_type,
    trigger_style)

  local margin_classes = {}
  for _, class in ipairs(el.classes) do
    if class == 'column-margin' or class == 'aside' or class == 'margin' then
      table.insert(margin_classes, class)
    end
  end

  local trigger_div = pandoc.Div(
    { pandoc.RawBlock('html', trigger_html) },
    pdoc.attr('', margin_classes)
  )

  return pandoc.Div({
    trigger_div,
    offcanvas_div
  })
end

-- ============================================================================
-- COMBINED DIV FILTER
-- ============================================================================

--- Process all Div elements (offcanvas and margin overtake)
--- @param el pandoc.Div Pandoc Div element
--- @return pandoc.Div|pandoc.Null Processed element
local function process_div(el)
  if pdoc.has_class(el.classes, 'offcanvas') then
    return process_offcanvas(el)
  end

  return convert_margin_to_offcanvas(el)
end

-- ============================================================================
-- FILTER EXPORT
-- ============================================================================

--- Initialise offcanvas CSS dependency
if quarto.doc.is_format('html:js') and quarto.doc.has_bootstrap() then
  html_mod.ensure_html_dependency({
    name = 'quarto-offcanvas',
    version = '1.0.0',
    stylesheets = { 'offcanvas.css' }
  })
end

return {
  { Meta = get_offcanvas_meta },
  { Div = process_div },
  { Span = convert_margin_to_offcanvas }
}
