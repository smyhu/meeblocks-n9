import QtQuick 1.1
import com.nokia.meego 1.0
import "game.js" as G
import "strings.js" as S

// MeeBlocks: the whole game lives on this one portrait page.
// Screens: menu (also the pause screen), play, over (on top of the board), scores, about.
Page {
    id: page
    orientationLock: PageOrientation.LockPortrait

    property string screen: "menu"
    property bool running: false        // a game exists (playing or paused)
    property bool paused: false
    property bool clearing: false
    property int startLevel: 0
    property bool rainbow: false
    property bool ghost: true
    property bool sound: true
    // shared 8-bit sounds (games-common); a missing QtMultimediaKit only means silence
    Loader { id: sounds; source: "Sounds.qml" }
    function sfx(name) { if (sound && sounds.item) sounds.item.play(name) }
    property int score: 0
    property int lines: 0
    property int level: 0
    property int best: 0
    property int place: 0               // place of the last game in TOP 10 (0 = none)
    property variant scores: []
    property variant fullRows: []
    property int flashCount: 0
    property int lockResets: 0
    property bool askClear: false

    // board geometry
    property int cell: 32
    property int boardX: 12
    property int boardY: 110

    property string lang: String(helper.language).substring(0, 2).toLowerCase()
    function tr(k) { return S.trl(k, page.lang) }

    // ---------- colours ----------
    property variant greenSet: ["#000000", "#E7FFCD", "#cfeca0", "#b5d98a", "#E7FFCD", "#cfeca0", "#b5d98a", "#9cc575", "#ffffff"]
    property variant rainbowSet: ["#000000", "#5fd3e8", "#f0d860", "#b884e0", "#78d068", "#e86a5a", "#6a8ef0", "#f0a050", "#ffffff"]
    function col(v) { return (rainbow ? rainbowSet : greenSet)[v] }

    // ---------- settings and scores ----------
    function loadAll() {
        startLevel = parseInt(helper.setting("startLevel", 0), 10) || 0
        rainbow = String(helper.setting("rainbow", false)) == "true"
        ghost = String(helper.setting("ghost", true)) == "true"
        sound = String(helper.setting("sound", true)) == "true"
        var list = []
        try { list = JSON.parse(helper.loadScores()) } catch (e) { list = [] }
        if (!(list instanceof Array)) list = []
        scores = list
        best = list.length > 0 ? list[0].s : 0
    }

    function addScore() {
        place = 0
        if (score <= 0) return
        var list = []
        for (var i = 0; i < scores.length; i++) list.push(scores[i])
        var entry = { s: score, l: lines, v: level, d: helper.today() }
        var pos = list.length
        for (i = 0; i < list.length; i++) if (score > list[i].s) { pos = i; break }
        if (pos >= 10) return
        list.splice(pos, 0, entry)
        if (list.length > 10) list = list.slice(0, 10)
        scores = list
        best = list[0].s
        place = pos + 1
        helper.saveScores(JSON.stringify(list))
    }

    // ---------- game flow ----------
    function newGame() {
        G.start(startLevel)
        slide = false; falling = false; dropAnim.stop(); dropOffset = 0
        running = true; paused = false; clearing = false; place = 0
        lockResets = 0
        lockTimer.stop()
        screen = "play"
        sync()
        helper.keepScreenOn(true)
    }

    function pause() {
        if (!running || screen != "play") return
        paused = true
        screen = "menu"
        helper.keepScreenOn(false)
    }

    function resume() {
        if (!running) return
        paused = false
        screen = "play"
        helper.keepScreenOn(true)
    }

    function gameOver() {
        running = false; paused = false
        lockTimer.stop()
        sync()
        addScore()
        screen = "over"
        sfx(place == 1 ? "record" : "gameover")
        helper.keepScreenOn(false)
    }

    function sync() {
        score = G.score; lines = G.lines; level = G.level
        render()
        renderNext()
    }

    // after any successful move: handle the lock delay
    function afterMove(resetLock) {
        if (G.grounded()) {
            if (!lockTimer.running) lockTimer.start()
            else if (resetLock && lockResets < 12) { lockResets++; lockTimer.restart() }
        } else {
            lockTimer.stop()
        }
        render()
    }

    function doLock() {
        lockTimer.stop()
        falling = false; dropOffset = 0
        lockResets = 0
        var full = G.lock()
        if (G.over) { gameOver(); return }
        if (full.length > 0) {
            fullRows = full
            sfx("eat")
            clearing = true
            flashCount = 0
            render()
            flashTimer.start()
            return
        }
        spawnNext()
    }

    function spawnNext() {
        if (!G.spawn()) { gameOver(); return }
        slide = false
        sync()
        gravity.restart()
    }

    // ---------- drawing ----------
    property variant shown: []
    property bool slide: false          // animate the piece layer (off right after spawn)
    property bool falling: false        // double-tap fast drop in progress
    function renderPiece() {
        var c = G.cur
        if (!c) { pieceLayer.visible = false; return }
        for (var i = 0; i < 4; i++) {
            var it = pieceRep.itemAt(i)
            it.x = 3 + (c.x + c.cells[i][0]) * cell
            it.y = 3 + (c.y + c.cells[i][1]) * cell
            it.v = c.id
        }
        pieceLayer.visible = true
        slide = true
    }
    function render() {
        renderPiece()
        var f = G.frame(ghost, false)
        if (clearing && flashCount % 2 == 0) {
            for (var k = 0; k < fullRows.length; k++)
                for (var c = 0; c < G.COLS; c++) f[fullRows[k] * G.COLS + c] = 8
        }
        for (var i = 0; i < f.length; i++) {
            var it = cells.itemAt(i)
            if (it && it.v !== f[i]) it.v = f[i]
        }
    }

    function renderNext() {
        var n = G.nextCells(), id = G.nextId
        var minX = 9, maxX = 0, minY = 9, maxY = 0
        for (var i = 0; i < 4; i++) {
            minX = Math.min(minX, n[i][0]); maxX = Math.max(maxX, n[i][0])
            minY = Math.min(minY, n[i][1]); maxY = Math.max(maxY, n[i][1])
        }
        var w = (maxX - minX + 1) * 22, h = (maxY - minY + 1) * 22
        for (i = 0; i < 4; i++) {
            var it = nextRep.itemAt(i)
            it.x = (nextBox.width - w) / 2 + (n[i][0] - minX) * 22
            it.y = (nextBox.height - h) / 2 + (n[i][1] - minY) * 22
            it.v = id
        }
    }

    // ---------- timers ----------
    Timer {
        id: gravity
        interval: G.speed() + 0 * page.level
        repeat: true
        running: page.screen == "play" && page.running && !page.paused && !page.clearing && !page.falling
        onTriggered: {
            if (G.down()) { afterMove(false); if (interval >= 100) sfx("move") }
            else if (!lockTimer.running) lockTimer.start()
        }
    }
    // double tap: the piece is moved to its landing row at once in the logic and the
    // picture slides down in ONE animation (accelerating), then it locks.
    property real dropOffset: 0
    function fastDrop() {
        if (!G.cur) return
        lockTimer.stop()
        var rows = G.hardDrop()              // logic: piece now on its landing row, +2 pts/row
        page.score = G.score
        if (rows <= 0) { doLock(); return }
        falling = true
        slide = false
        dropOffset = -rows * cell            // keep the picture where it was ...
        renderPiece()
        slide = false
        dropAnim.duration = Math.min(320, 90 + rows * 12)
        dropAnim.start()                     // ... and slide it down to the landing row
    }
    NumberAnimation {
        id: dropAnim
        target: page; property: "dropOffset"; to: 0
        easing.type: Easing.InQuad
        onRunningChanged: if (!running && page.falling) { page.dropOffset = 0; page.sfx("move"); page.doLock() }
    }
    Timer {
        id: lockTimer
        interval: 450
        onTriggered: { if (G.grounded()) doLock(); else render() }
    }
    Timer {
        id: flashTimer
        interval: 70
        repeat: true
        onTriggered: {
            flashCount++
            if (flashCount >= 6) {
                stop()
                G.clearRows(fullRows)
                clearing = false
                fullRows = []
                spawnNext()
            } else render()
        }
    }

    Connections {
        target: typeof(platformWindow) != "undefined" ? platformWindow : null
        ignoreUnknownSignals: true
        onActiveChanged: if (!platformWindow.active) page.pause()
    }

    Component.onCompleted: { loadAll(); G.newField() }

    // ---------- background ----------
    Image { anchors.fill: parent; source: "background.png"; fillMode: Image.Stretch }

    // ================= PLAY =================
    Item {
        id: playScreen
        anchors.fill: parent
        visible: page.screen == "play" || page.screen == "over"

        PixelText { x: page.boardX; y: 44; text: tr("title"); pixelSize: 4 }

        // pause square, top right
        Rectangle {
            id: pauseBtn
            x: 480 - 12 - 64; y: 26; width: 64; height: 64
            color: (touch.pressed && touch.onPause) ? "#E7FFCD" : "#0c120a"
            border.width: 2; border.color: "#5f7f45"
            visible: page.screen == "play"
            Row {
                anchors.centerIn: parent; spacing: 8
                Rectangle { width: 8; height: 24; color: (touch.pressed && touch.onPause) ? "#0c120a" : "#E7FFCD" }
                Rectangle { width: 8; height: 24; color: (touch.pressed && touch.onPause) ? "#0c120a" : "#E7FFCD" }
            }
        }

        // the well
        Rectangle {
            id: board
            x: page.boardX; y: page.boardY
            width: G.COLS * page.cell + 4; height: G.ROWS * page.cell + 4
            color: "#0c120a"
            border.width: 2; border.color: "#5f7f45"
            Repeater {
                id: cells
                model: 200
                Rectangle {
                    property int v: 0
                    x: 2 + (index % 10) * page.cell + 1
                    y: 2 + Math.floor(index / 10) * page.cell + 1
                    width: page.cell - 2; height: page.cell - 2
                    color: v > 0 ? page.col(v) : "transparent"
                    border.width: v < 0 ? 2 : 0
                    border.color: v < 0 ? page.col(-v) : "transparent"
                    opacity: v < 0 ? 0.45 : 1
                    visible: v != 0
                }
            }
        }

        // falling piece in its own layer so moves and rotations slide smoothly
        Item {
            id: pieceLayer
            x: board.x; y: board.y; width: board.width; height: board.height
            visible: false
            clip: true
            Item {
            width: parent.width; height: parent.height
            y: page.dropOffset
            Repeater {
                id: pieceRep
                model: 4
                Rectangle {
                    property int v: 1
                    width: page.cell - 2; height: page.cell - 2
                    color: page.col(v)
                    Behavior on x { enabled: page.slide; NumberAnimation { duration: 60 } }
                    Behavior on y { enabled: page.slide; NumberAnimation { duration: 60 } }
                }
            }
            }
        }

        // side panel
        Column {
            x: board.x + board.width + 14; y: page.boardY
            width: 480 - x - 12
            spacing: 6
            PixelText { text: tr("next"); pixelSize: 2 }
            Rectangle {
                id: nextBox
                width: parent.width; height: 70
                color: "#0c120a"; border.width: 2; border.color: "#5f7f45"
                Repeater {
                    id: nextRep
                    model: 4
                    Rectangle {
                        property int v: 1
                        width: 20; height: 20
                        color: page.col(v)
                        visible: page.running || page.screen == "over"
                    }
                }
            }
            Item { width: 1; height: 18 }
            PixelText { text: tr("score"); pixelSize: 2 }
            PixelText { text: String(page.score); pixelSize: 3 }
            Item { width: 1; height: 12 }
            PixelText { text: tr("lines"); pixelSize: 2 }
            PixelText { text: String(page.lines); pixelSize: 3 }
            Item { width: 1; height: 12 }
            PixelText { text: tr("level"); pixelSize: 2 }
            PixelText { text: String(page.level); pixelSize: 3 }
            Item { width: 1; height: 12 }
            PixelText { text: tr("best"); pixelSize: 2; color: "#cfeca0" }
            PixelText { text: String(Math.max(page.best, page.score)); pixelSize: 3; color: "#cfeca0" }
        }

        // touch control: slide left/right = move (follows the finger),
        // slide up/down = rotate, double tap = fast drop to the bottom (confirms the shadow)
        MouseArea {
            id: touch
            anchors.fill: parent
            enabled: page.screen == "play"
            property real ax: 0
            property real ay: 0
            property real sx: 0
            property real sy: 0
            property double t0: 0
            property double lastTap: 0
            property real tapX: 0
            property real tapY: 0
            property string axis: ""
            property bool onPause: false
            property int stepX: 26
            property int stepY: 44

            function busy() { return page.clearing || !page.running || page.falling }
            onPressed: {
                onPause = mouse.x >= pauseBtn.x - 8 && mouse.y <= pauseBtn.y + pauseBtn.height + 8
                ax = mouse.x; ay = mouse.y; sx = mouse.x; sy = mouse.y
                t0 = new Date().getTime(); axis = ""
            }
            onPositionChanged: {
                if (onPause || busy()) return
                var dx = mouse.x - ax, dy = mouse.y - ay
                if (axis == "") {
                    var mx = Math.abs(mouse.x - sx), my = Math.abs(mouse.y - sy)
                    if (mx > 12 && mx >= my) axis = "x"
                    else if (my > 16) axis = "y"
                }
                if (axis == "x") {
                    while (dx >= stepX) { ax += stepX; dx -= stepX; if (G.move(1)) { afterMove(true); sfx("move") } }
                    while (dx <= -stepX) { ax -= stepX; dx += stepX; if (G.move(-1)) { afterMove(true); sfx("move") } }
                } else if (axis == "y") {
                    // up = clockwise, down = counter-clockwise; one turn per stepY of travel
                    while (dy <= -stepY) { ay -= stepY; dy += stepY; if (G.rotate(1)) { afterMove(true); sfx("move") } }
                    while (dy >= stepY) { ay += stepY; dy -= stepY; if (G.rotate(-1)) { afterMove(true); sfx("move") } }
                }
            }
            onReleased: {
                var now = new Date().getTime()
                var moved = Math.abs(mouse.x - sx) + Math.abs(mouse.y - sy)
                if (onPause) {
                    if (moved < 30) page.pause()
                    return
                }
                if (busy()) return
                if (axis == "y" && moved >= 16 && moved < stepY) {
                    // a short flick also turns the piece once
                    if (G.rotate(mouse.y < sy ? 1 : -1)) { afterMove(true); sfx("move") }
                    return
                }
                if (axis == "" && moved < 24 && now - t0 < 350) {
                    if (now - lastTap < 400 && Math.abs(mouse.x - tapX) < 60 && Math.abs(mouse.y - tapY) < 60) {
                        lastTap = 0
                        lockTimer.stop()
                        page.fastDrop()
                    } else {
                        lastTap = now; tapX = mouse.x; tapY = mouse.y
                    }
                }
            }
        }

        // game over panel on top of the board
        Rectangle {
            visible: page.screen == "over"
            x: board.x + 2; width: board.width - 4
            y: board.y + 130; height: 380
            color: "#0c120a"; border.width: 2; border.color: "#E7FFCD"
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 24; spacing: 16
                PixelText { anchors.horizontalCenter: parent.horizontalCenter; text: tr("gameOver"); pixelSize: 4 }
                PixelText { anchors.horizontalCenter: parent.horizontalCenter; text: String(page.score); pixelSize: 5 }
                PixelText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.place == 1 ? tr("newRecord") : tr("place").replace("%1", page.place)
                    visible: page.place > 0; pixelSize: 2; color: "#cfeca0"
                }
                PixelButton { width: 280; text: tr("newGame"); onClicked: page.newGame() }
                PixelButton { width: 280; text: tr("menu"); onClicked: page.screen = "menu" }
            }
        }
    }

    // ================= MENU / PAUSE =================
    Item {
        anchors.fill: parent
        visible: page.screen == "menu"

        PixelText {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 70; text: page.paused ? tr("paused") : tr("title"); pixelSize: 6
        }
        // a few flat blocks as a logo strip
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 140; spacing: 2
            Repeater {
                model: [3, 3, 3, 0, 1, 1, 1, 1, 0, 5, 5, 0, 2, 2]
                Rectangle { width: 22; height: 22; color: modelData == 0 ? "transparent" : page.col(modelData) }
            }
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 210; spacing: 14
            PixelButton { text: tr("resume"); visible: page.paused; onClicked: page.resume() }
            PixelButton { text: tr("newGame"); onClicked: page.newGame() }
            // start level chooser: < LEVEL n >
            Rectangle {
                width: 400; height: 72; color: "#0c120a"; border.width: 4; border.color: "#E7FFCD"
                PixelText { anchors.centerIn: parent; text: tr("level") + " " + page.startLevel; pixelSize: 4 }
                Rectangle {
                    width: 64; height: parent.height; color: lessArea.pressed ? "#E7FFCD" : "transparent"
                    PixelText { anchors.centerIn: parent; text: "<"; pixelSize: 4; color: lessArea.pressed ? "#0c120a" : "#E7FFCD" }
                    MouseArea { id: lessArea; anchors.fill: parent
                        onClicked: { page.startLevel = (page.startLevel + 9) % 10; helper.setSetting("startLevel", page.startLevel) } }
                }
                Rectangle {
                    anchors.right: parent.right
                    width: 64; height: parent.height; color: moreArea.pressed ? "#E7FFCD" : "transparent"
                    PixelText { anchors.centerIn: parent; text: ">"; pixelSize: 4; color: moreArea.pressed ? "#0c120a" : "#E7FFCD" }
                    MouseArea { id: moreArea; anchors.fill: parent
                        onClicked: { page.startLevel = (page.startLevel + 1) % 10; helper.setSetting("startLevel", page.startLevel) } }
                }
            }
            PixelButton {
                text: tr("colours") + " " + (page.rainbow ? tr("atari") : tr("green"))
                onClicked: { page.rainbow = !page.rainbow; helper.setSetting("rainbow", page.rainbow); page.render() }
            }
            PixelButton {
                text: tr("ghost") + " " + (page.ghost ? tr("on") : tr("off"))
                onClicked: { page.ghost = !page.ghost; helper.setSetting("ghost", page.ghost) }
            }
            PixelButton {
                text: tr("sound") + " " + (page.sound ? tr("on") : tr("off"))
                onClicked: { page.sound = !page.sound; helper.setSetting("sound", page.sound); page.sfx("eat") }
            }
            Row {
                spacing: 10
                PixelButton { width: 195; text: tr("scores"); onClicked: { page.askClear = false; page.screen = "scores" } }
                PixelButton { width: 195; text: tr("about"); onClicked: page.screen = "about" }
            }
        }
    }

    // ================= TOP 10 =================
    Item {
        anchors.fill: parent
        visible: page.screen == "scores"
        PixelText { anchors.horizontalCenter: parent.horizontalCenter; y: 60; text: tr("scores"); pixelSize: 6 }
        Rectangle {
            x: 12; y: 140; width: 456; height: 520
            color: "#0c120a"; border.width: 2; border.color: "#5f7f45"
            PixelText {
                anchors.centerIn: parent; visible: page.scores.length == 0
                text: tr("noScores"); pixelSize: 3
            }
            Column {
                x: 16; y: 16; spacing: 10
                Repeater {
                    model: page.scores
                    Row {
                        spacing: 0
                        PixelText { width: 52; text: (index + 1) + "."; pixelSize: 3; color: index == page.place - 1 ? "#ffffff" : "#cfeca0" }
                        PixelText { width: 150; text: String(modelData.s); pixelSize: 3; color: index == page.place - 1 ? "#ffffff" : "#E7FFCD" }
                        PixelText { width: 70; text: "L" + modelData.v; pixelSize: 2; color: "#9cc575"; anchors.verticalCenter: parent.verticalCenter }
                        PixelText { text: String(modelData.d); pixelSize: 2; color: "#9cc575"; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 690; spacing: 16
            PixelButton { width: 220; text: page.askClear ? tr("yes") : tr("clear"); enabled: page.scores.length > 0
                onClicked: {
                    if (!page.askClear) { page.askClear = true; return }
                    page.askClear = false; page.scores = []; page.best = 0; page.place = 0
                    helper.saveScores("[]")
                } }
            PixelButton { width: 220; text: page.askClear ? tr("no") : tr("back")
                onClicked: { if (page.askClear) page.askClear = false; else page.screen = "menu" } }
        }
        PixelText {
            anchors.horizontalCenter: parent.horizontalCenter; y: 780
            visible: page.askClear; text: tr("clearAsk"); pixelSize: 3; color: "#ff7a6a"
        }
    }

    // ================= ABOUT =================
    Item {
        anchors.fill: parent
        visible: page.screen == "about"
        Image { anchors.horizontalCenter: parent.horizontalCenter; y: 50; source: "meeblocks80.png" }
        PixelText { anchors.horizontalCenter: parent.horizontalCenter; y: 150; text: tr("title"); pixelSize: 5 }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter; y: 200
            text: helper.version; color: "#8C8C8C"; font.family: "Nokia Pure Text"; font.pixelSize: 20
        }
        Column {
            x: 32; y: 250; width: 416; spacing: 22
            Text { width: parent.width; wrapMode: Text.WordWrap; color: "white"; font.family: "Nokia Pure Text"; font.pixelSize: 24; text: tr("aboutText") }
            Text { width: parent.width; wrapMode: Text.WordWrap; color: "#cfeca0"; font.family: "Nokia Pure Text"; font.pixelSize: 22; text: tr("help") }
            Text {
                width: parent.width; wrapMode: Text.WordWrap; color: "#8C8C8C"; font.family: "Nokia Pure Text"; font.pixelSize: 20
                textFormat: Text.RichText
                text: tr("credit") + "<br><a style='color:#cfeca0' href='https://github.com/smyhu'>github.com/smyhu</a>"
                onLinkActivated: Qt.openUrlExternally(link)
            }
        }
        PixelButton { anchors.horizontalCenter: parent.horizontalCenter; y: 760; text: tr("back"); onClicked: page.screen = "menu" }
    }
}
