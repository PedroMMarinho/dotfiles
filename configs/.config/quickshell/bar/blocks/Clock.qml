import QtQuick
import "../"

BarBlock {
  id: root
  content: BarText {
    pointSize: 11
    symbolText: `${Datetime.date} ${Datetime.time}`
  }
}
