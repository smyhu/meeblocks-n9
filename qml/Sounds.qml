import QtQuick 1.1
import QtMultimediaKit 1.1

// 8-bit sound effects (sounds/*.wav, made by tools/make-sounds.py).
// Loaded through a Loader: if QtMultimediaKit is missing the game simply stays silent.
Item {
    property bool on: true
    property bool tock: false

    function play(name) {
        if (!on) return;
        if (name == "move") { tock = !tock; (tock ? move2 : move1).play(); }
        else if (name == "eat") eat.play();
        else if (name == "bonus") bonus.play();
        else if (name == "crash") crash.play();
        else if (name == "gameover") gameover.play();
        else if (name == "record") record.play();
    }

    SoundEffect { id: move1; source: "sounds/move1.wav"; volume: 0.5 }
    SoundEffect { id: move2; source: "sounds/move2.wav"; volume: 0.5 }
    SoundEffect { id: eat; source: "sounds/eat.wav" }
    SoundEffect { id: bonus; source: "sounds/bonus.wav" }
    SoundEffect { id: crash; source: "sounds/crash.wav" }
    SoundEffect { id: gameover; source: "sounds/gameover.wav" }
    SoundEffect { id: record; source: "sounds/record.wav" }
}
