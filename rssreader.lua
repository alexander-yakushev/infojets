local string     = string
local io         = io
local ipairs     = ipairs
local wibox      = require("wibox")
local layout     = require("infojets.layout.flex")
local awful      = awful
local print      = print
local table      = table
local feedparser = require("feedparser")
local util       = infojets.util
local pango      = util.pango
local naughty    = naughty

-- Onscreen rss reader widget.
-- Usage:
-- wbox = infojets.create_wibox({x = 30, y = 730, width = 500, height = 300, bg_color = "#22222200" })
-- local rssreader = infojets.rssreader.new({ max_items = 20 })
-- rssreader:add_source("http://some.rss/feed")
-- rssreader:run()
-- wbox.set_widget(rssreader.widget)
module("infojets.rssreader")

-- Initialize object with widget
function new(args)
   w              = {}
   -- Max numbers of items in the widget box
   w.max_items    = args.max_items or 10
   -- Foreground color of text in widget box 
   w.foreground   = args.foreground or "#000000"
   -- Font of text in widget box
   w.font         = args.font or "sans 9"

   -- Do not change this properties manually!
   w.sources      = {}
   w.entries      = {}

   -- Function delegation
   w.init_widgets = init_widgets
   w.run          = run
   w.update       = update
   w.refresh      = refresh
   w.add_source   = add_source

   return w
end

-- Initialize widget appearance
function init_widgets(w)

   -- Used for saving references of textbox
   local ui        = {}
   ui.articles     = {}

   -- Body widget
   local body = wibox.layout.fixed.vertical();

   -- Mark all as read button
   local mark_all = wibox.widget.textbox()

   mark_all:set_markup(pango("<u>Mark all as read</u>\n", { foreground = "black" }, false))
   mark_all:buttons(awful.button({ }, 1, 
   function ()
      for _, entry in ipairs(w.entries) do
         entry.is_unread = false
      end
      w:refresh()
   end
   ))
   body:add(mark_all)

   -- Adding textbox widgets to body
   for i = 1, w.max_items do
      local tbox = wibox.widget.textbox()
      table.insert(ui.articles, tbox)
      body:add(tbox)
   end

   w.ui          = ui
   w.ui.mark_all = mark_all
   w.widget      = body
end

-- Updates widget's data
function update(w)

   -- Aliasing
   local entries = w.entries

   -- Fetch all articles to this array
   local all_entries = {}
   for _, source in ipairs(w.sources) do

      -- Use curl for fetching data
      local f = io.popen("curl --silent " .. source):read("*all")
      -- Parse it with feedparser
      local data, err = feedparser.parse(f)

      -- Extract only needed values
      for _, entry in ipairs(data.entries) do

         local new_entry = {
            title     = entry.title,
            link      = entry.links[1].href,
            feed      = data.feed.title,
            timestamp = entry.updated_parsed,
            is_unread = true
         }

         --Insert into array of all entries
         table.insert(all_entries, new_entry)
      end
   end

   -- Sort entries by timestamp
   table.sort(all_entries, function(a, b) return a.timestamp > b.timestamp end)

   -- If entries not field out
   if #entries ~= w.max_items then
      -- make first fillin
      for i = 1, w.max_items do
         table.insert(entries, all_entries[i])
      end
      -- If entries is full
   else
      local first_entry = entries[1]
      for i = w.max_items, 1, -1 do
         local new_entry = all_entries[i]

         -- If entry is newer
         if new_entry.timestamp > first_entry.timestamp then
            --delete last item
            delete_last(entries)
            -- and insert new item as first
            table.insert(entries, 1, new_entry)
            -- notify user
            naughty.notify({ 
               preset  = naughty.config.presets.normal,
               title   = new_entry.title,
               text    = new_entry.title,
               timeout = 7 
            })
         end
      end
   end

   -- Redraw widget
   w:refresh()
end

-- Redraws widget
function refresh(w)

   for i = 1, w.max_items do

      -- Set widget text
      local entry = w.entries[i]
      local text  = pango(entry.title, {}, true)
      text        = string.format("<span foreground = %q>%s - [<i>%s</i>]</span>\n", w.foreground, text, entry.feed)
      -- If entry is new - make it bold
      if entry.is_unread then text = string.format("<b>%s</b>", text) end

      w.ui.articles[i]:set_markup(text)

      -- Set widget buttons
      w.ui.articles[i]:buttons(awful.util.table.join(
      -- On the left click - open in browser
      awful.button({ }, 1, function ()
         awful.util.spawn("xdg-open " .. entry.link)
         entry.is_unread = false
         w:refresh()
      end),

      -- On the middle click - mark as read
      awful.button({ }, 2, function ()
         entry.is_unread = false
         w:refresh()
      end)
      ))
   end
end

-- Fully initialize widget
function run(w)

   w:init_widgets()

   w:update()

   util.repeat_every(function ()
      w:update()
   end, 60)
end

-- Adds source to widget list
function add_source(w, url)
   table.insert(w.sources, url)
end

-- Delete last item in table
function delete_last(t)
   t[#t] = nil
end

-- vim:ts=3 ss=3 sw=3 expandtab
