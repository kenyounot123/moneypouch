module ShortcutsHelper
  # Ordered so the cheat sheet's two columns come out even, with Anywhere and Searching on the left.
  def shortcut_groups
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
      ],
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

  private
    def single_key_shortcuts
      if Current.user.single_key_shortcuts?
        [ [ "Search transactions", [ "/" ] ], [ "Show these shortcuts", [ "?" ] ] ]
      else
        []
      end
    end
end
