module ShortcutsHelper
  def shortcut_columns
    [ anywhere_and_search_shortcuts, adding_and_editing_shortcuts ]
  end

  private
    def anywhere_and_search_shortcuts
      {
        "Anywhere" => [
          [ "Add a transaction", [ shortcut("K") ] ],
          [ "Undo the last add", [ shortcut("Z") ] ],
          [ "Show or hide the sidebar", [ shortcut("B") ] ],
          *single_key_shortcuts,
          [ "Previous or next month", [ "←", "→" ] ]
        ],
        "Searching" => [
          [ "Move through suggestions", [ "↑", "↓" ] ],
          [ "Add a filter", [ "Enter" ] ],
          [ "Remove the last filter", [ mac? ? "Delete" : "Backspace" ] ],
          [ "Leave search", [ "Esc" ] ]
        ]
      }
    end

    def adding_and_editing_shortcuts
      {
        "Adding a transaction" => [
          [ "Finish a name or day", [ "Tab" ] ],
          [ "Move through suggestions", [ "↑", "↓" ] ],
          [ "Pick a suggestion", [ "Enter" ] ],
          [ "Close the suggestions", [ "Esc" ] ],
          [ "Calendar day or week", [ "←", "→", "↑", "↓" ] ],
          [ "Calendar month", [ "PgUp", "PgDn" ] ],
          [ "Calendar year", [ "Shift PgUp", "Shift PgDn" ] ]
        ],
        "Editing a note or category" => [
          [ "Save", [ "Enter" ] ],
          [ "Cancel", [ "Esc" ] ]
        ]
      }
    end

    def single_key_shortcuts
      if Current.user.single_key_shortcuts?
        [ [ "Search transactions", [ "/" ] ], [ "Show these shortcuts", [ "?" ] ] ]
      else
        []
      end
    end
end
