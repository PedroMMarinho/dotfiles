import QtQuick
import "../"

BarBlock {
  id: root
  content: BarText {
    pointSize: 10
    symbolText: `${Datetime.date} ${Datetime.time}`
  }
}
