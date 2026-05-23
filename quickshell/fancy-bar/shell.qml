import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "./modules/bar/"
import "./modules/common/"
import "./services/"

ShellRoot{
    Scope {
        Variants {
            model: Quickshell.screens
            delegate: Component {
                Bar {
                    required property var modelData
                    position: Types.stringToPosition(Config.data.bar.position)
                    size: Config.data.bar.size
                    color: Config.data.theme.colors.background
                    screen: modelData
                }
            }
        }
    }
}
