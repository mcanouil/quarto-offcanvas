--- @module offcanvas
--- @license MIT
--- @copyright 2026 Mickaël Canouil
--- @author Mickaël Canouil

--- Extension name constant
local EXTENSION_NAME = 'offcanvas'

--- Constants for trigger text extraction
local MAX_TEXT_EXTRACT = 50
local MAX_TRIGGER_LENGTH = 30
local TRUNCATE_LENGTH = 27

--- Valid placement and responsive values (hash tables for O(1) lookup)
local VALID_PLACEMENTS = { start = true, ['end'] = true, top = true, bottom = true }
local VALID_RESPONSIVE = { sm = true, md = true, lg = true, xl = true, xxl = true }
local VALID_TRIGGER_POSITIONS = { inline = true, none = true }

--- Load required modules
local utils = require(quarto.utils.resolve_path('_modules/utils.lua'):gsub('%.lua$', ''))
local content = require(quarto.utils.resolve_path('_modules/content-extraction.lua'):gsub('%.lua$', ''))
local schema = require(quarto.utils.resolve_path('_modules/schema.lua'):gsub('%.lua$', ''))

--- Generate unique offcanvas ID
--- @type integer Counter for unique offcanvas IDs
local offcanvas_count = 0

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
local offcanvas_settings_meta = {
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
  ['show-close'] = 'true',
  responsive = '',
  ['overtake-margins'] = 'false'
}

--- Get offcanvas option from metadata
--- @param key string The option name to retrieve
--- @param meta table Document metadata table
--- @return string The option value as a string
local function get_offcanvas_option(key, meta)
  if meta['extensions'] and meta['extensions']['offcanvas'] and meta['extensions']['offcanvas'][key] then
    return utils.stringify(meta['extensions']['offcanvas'][key])
  end

  return offcanvas_settings_meta[key] or ''
end

--- Extract and configure offcanvas settings from document metadata
--- @param meta table Document metadata table
--- @return table Updated metadata table with offcanvas configuration
local function get_offcanvas_meta(meta)
  schema.validate_options(meta, EXTENSION_NAME, quarto.utils.resolve_path('_schema.yml'))

  for key, _ in pairs(offcanvas_settings_meta) do
    local option_value = get_offcanvas_option(key, meta)
    offcanvas_settings_meta[key] = option_value
  end

  meta['extensions'] = meta['extensions'] or {}
  meta['extensions']['offcanvas'] = meta['extensions']['offcanvas'] or {}
  for key, value in pairs(offcanvas_settings_meta) do
    meta['extensions']['offcanvas'][key] = value
  end

  return meta
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--- Escape HTML special characters to prevent XSS
--- @param str string String to escape
--- @return string Escaped string safe for HTML
local function escape_html(str)
  if not str or str == '' then
    return ''
  end

  local escape_chars = {
    ['&'] = '&amp;',
    ['<'] = '&lt;',
    ['>'] = '&gt;',
    ['"'] = '&quot;',
    ["'"] = '&#39;'
  }

  return (str:gsub('[&<>"\']', escape_chars))
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

-- ============================================================================
-- OFFCANVAS STRUCTURE GENERATION
-- ============================================================================

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

  local offcanvas_classes = { 'offcanvas', 'offcanvas-' .. placement }

  if responsive and responsive ~= '' then
    if VALID_RESPONSIVE[responsive] then
      table.insert(offcanvas_classes, 'offcanvas-' .. responsive)
    else
      utils.log_warning(EXTENSION_NAME, 'Invalid responsive breakpoint "' .. responsive .. '". Ignoring.')
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

  local offcanvas_header = pandoc.Div(header_blocks, utils.attr('', { 'offcanvas-header' }))

  local offcanvas_body = pandoc.Div(body_blocks, utils.attr('', { 'offcanvas-body' }))

  local offcanvas_content = { offcanvas_header, offcanvas_body }

  if footer_blocks and #footer_blocks > 0 then
    local offcanvas_footer = pandoc.Div(footer_blocks, utils.attr('', { 'offcanvas-footer' }))
    table.insert(offcanvas_content, offcanvas_footer)
  end

  local offcanvas_div = pandoc.Div(
    offcanvas_content,
    utils.attr(offcanvas_id, offcanvas_classes, offcanvas_attrs)
  )

  local style_attr = ''
  if placement == 'start' or placement == 'end' then
    style_attr = 'width: ' .. width .. ';'
  elseif placement == 'top' or placement == 'bottom' then
    style_attr = 'height: ' .. height .. ';'
  end

  if style_attr ~= '' then
    offcanvas_div.attributes.style = style_attr
  end

  return offcanvas_div
end

-- ============================================================================
-- TRIGGER GENERATION
-- ============================================================================

--- Generate trigger button HTML
--- @param offcanvas_id string ID of the offcanvas element
--- @param trigger_text string Button text
--- @param trigger_class string CSS classes for the button
--- @param trigger_icon string Icon class (optional)
--- @param trigger_type string Type of trigger ('button' or 'text')
--- @return string HTML for trigger button
local function generate_trigger(offcanvas_id, trigger_text, trigger_class, trigger_icon, trigger_type)
  local escaped_id = escape_html(offcanvas_id)
  local escaped_text = escape_html(trigger_text)
  local escaped_icon = escape_html(trigger_icon)
  local escaped_class = escape_html(trigger_class)

  local icon_html = ''
  if trigger_icon and trigger_icon ~= '' then
    icon_html = '<i class="' .. escaped_icon .. '"></i> '
  end

  local class_attr = ''
  if trigger_class and trigger_class ~= 'none' and trigger_class ~= '' then
    class_attr = ' class="' .. escaped_class .. '"'
  end

  local html = ''
  if trigger_type == 'text' then
    html = '<span' .. class_attr .. ' ' ..
        'data-bs-toggle="offcanvas" data-bs-target="#' .. escaped_id .. '" ' ..
        'aria-controls="' .. escaped_id .. '" style="cursor: pointer;">' ..
        icon_html .. escaped_text ..
        '</span>'
  else
    html = '<button' .. class_attr .. ' type="button" ' ..
        'data-bs-toggle="offcanvas" data-bs-target="#' .. escaped_id .. '" ' ..
        'aria-controls="' .. escaped_id .. '">' ..
        icon_html .. escaped_text ..
        '</button>'
  end

  return html
end

-- ============================================================================
-- OFFCANVAS FILTER
-- ============================================================================

--- Filter for Divs with class 'offcanvas'
--- @param el pandoc.Div Pandoc Div element
--- @return pandoc.Div|pandoc.Null Pandoc Div structure for offcanvas, or Null if not applicable
local function process_offcanvas(el)
  if not quarto.doc.is_format('html:js') or not quarto.doc.has_bootstrap() or not utils.has_class(el.classes, 'offcanvas') then
    return el
  end

  local offcanvas_id = el.identifier ~= '' and el.identifier or unique_offcanvas_id()

  local placement = el.attributes.placement or offcanvas_settings_meta.placement
  local width = el.attributes.width or offcanvas_settings_meta.width
  local height = el.attributes.height or offcanvas_settings_meta.height
  local backdrop = el.attributes.backdrop or offcanvas_settings_meta.backdrop
  local scroll = el.attributes.scroll or offcanvas_settings_meta.scroll
  local keyboard = el.attributes.keyboard or offcanvas_settings_meta.keyboard
  local trigger_text = el.attributes['trigger-text'] or offcanvas_settings_meta['trigger-text']
  local trigger_class = el.attributes['trigger-class'] or offcanvas_settings_meta['trigger-class']
  local trigger_icon = el.attributes['trigger-icon'] or offcanvas_settings_meta['trigger-icon']
  local trigger_position = el.attributes['trigger-position'] or offcanvas_settings_meta['trigger-position']
  local trigger_type = el.attributes['trigger-type'] or offcanvas_settings_meta['trigger-type']
  local show_close = el.attributes['show-close'] or offcanvas_settings_meta['show-close']
  local responsive = el.attributes.responsive or offcanvas_settings_meta.responsive
  local title_override = el.attributes.title

  placement = normalise_placement(placement)

  if not VALID_PLACEMENTS[placement] then
    utils.log_warning(EXTENSION_NAME, 'Invalid placement "' .. placement .. '". Using "start".')
    placement = 'start'
  end

  local parsed = content.parse_sections(el.content)
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
    keyboard = keyboard
  })

  if not VALID_TRIGGER_POSITIONS[trigger_position] then
    utils.log_warning(EXTENSION_NAME, 'Invalid trigger-position "' .. trigger_position .. '". Using "inline".')
    trigger_position = 'inline'
  end

  if trigger_position == 'none' then
    return offcanvas_div
  end

  local trigger_html = generate_trigger(offcanvas_id, trigger_text, trigger_class, trigger_icon, trigger_type)

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
  if offcanvas_settings_meta['overtake-margins'] ~= 'true' then
    return el
  end

  if not quarto.doc.is_format('html:js') or not quarto.doc.has_bootstrap() then
    return el
  end

  local is_margin = utils.has_class(el.classes, 'column-margin') or
      utils.has_class(el.classes, 'aside') or
      utils.has_class(el.classes, 'margin')

  if not is_margin then
    return el
  end

  local offcanvas_id = el.identifier ~= '' and el.identifier or unique_offcanvas_id()

  local placement = el.attributes.placement or offcanvas_settings_meta.placement
  local width = el.attributes.width or offcanvas_settings_meta.width
  local height = el.attributes.height or offcanvas_settings_meta.height
  local backdrop = el.attributes.backdrop or offcanvas_settings_meta.backdrop
  local scroll = el.attributes.scroll or offcanvas_settings_meta.scroll
  local keyboard = el.attributes.keyboard or offcanvas_settings_meta.keyboard
  local trigger_class = el.attributes['trigger-class'] or offcanvas_settings_meta['trigger-class']
  local trigger_icon = el.attributes['trigger-icon'] or offcanvas_settings_meta['trigger-icon']
  local trigger_type = el.attributes['trigger-type'] or offcanvas_settings_meta['trigger-type']
  local show_close = el.attributes['show-close'] or offcanvas_settings_meta['show-close']
  local title_override = el.attributes.title

  placement = normalise_placement(placement)

  local trigger_text = el.attributes['trigger-text']
  if not trigger_text or trigger_text == '' then
    trigger_text = 'View margin content'
    if el.content and #el.content > 0 then
      local first_text = utils.stringify(el.content):sub(1, MAX_TEXT_EXTRACT)
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
    keyboard = keyboard
  })

  local trigger_html = generate_trigger(offcanvas_id, trigger_text, trigger_class, trigger_icon, trigger_type)

  local margin_classes = {}
  for _, class in ipairs(el.classes) do
    if class == 'column-margin' or class == 'aside' or class == 'margin' then
      table.insert(margin_classes, class)
    end
  end

  local trigger_div = pandoc.Div(
    { pandoc.RawBlock('html', trigger_html) },
    utils.attr('', margin_classes)
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
  if utils.has_class(el.classes, 'offcanvas') then
    return process_offcanvas(el)
  end

  return convert_margin_to_offcanvas(el)
end

-- ============================================================================
-- FILTER EXPORT
-- ============================================================================

--- Initialise offcanvas CSS dependency
if quarto.doc.is_format('html:js') and quarto.doc.has_bootstrap() then
  utils.ensure_html_dependency({
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
