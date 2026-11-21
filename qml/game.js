// MeeBlocks game logic: 10 x 20 well, 7 pieces, 7-bag, simple wall kicks.
// Copyright (c) 2026 smyhu. MIT License.
var COLS = 10, ROWS = 20;
// piece shapes in their own N x N box, spawn rotation; ids 1..7 = I O T S Z J L
var SHAPES = [
    null,
    { n: 4, c: [[0,1],[1,1],[2,1],[3,1]] },          // I
    { n: 2, c: [[0,0],[1,0],[0,1],[1,1]] },          // O
    { n: 3, c: [[1,0],[0,1],[1,1],[2,1]] },          // T
    { n: 3, c: [[1,0],[2,0],[0,1],[1,1]] },          // S
    { n: 3, c: [[0,0],[1,0],[1,1],[2,1]] },          // Z
    { n: 3, c: [[0,0],[0,1],[1,1],[2,1]] },          // J
    { n: 3, c: [[2,0],[0,1],[1,1],[2,1]] }           // L
];
var LINE_POINTS = [0, 40, 100, 300, 1200];
// gravity in ms per row for each level (classic curve, faster later)
var SPEED = [800, 717, 633, 550, 467, 383, 300, 217, 133, 100, 83, 83, 83, 67, 67, 67, 50, 50, 50, 33];
var KICKS = [[0,0],[-1,0],[1,0],[0,-1],[-2,0],[2,0]];

var field = [];          // ROWS*COLS, 0 = empty, else piece id
var cur = null;          // { id, n, cells:[[x,y]..], x, y }
var nextId = 0;
var bag = [];
var score = 0, lines = 0, level = 0, startLevel = 0;
var over = false;

function newField() {
    field = [];
    for (var i = 0; i < ROWS * COLS; i++) field.push(0);
}

function takeFromBag() {
    if (bag.length === 0) {
        bag = [1, 2, 3, 4, 5, 6, 7];
        for (var i = bag.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1));
            var t = bag[i]; bag[i] = bag[j]; bag[j] = t;
        }
    }
    return bag.pop();
}

function cellsOf(id) {
    var s = SHAPES[id], out = [];
    for (var i = 0; i < 4; i++) out.push([s.c[i][0], s.c[i][1]]);
    return out;
}

function rotated(cells, n, dir) {          // dir 1 = clockwise, -1 = counter
    var out = [];
    for (var i = 0; i < cells.length; i++) {
        var x = cells[i][0], y = cells[i][1];
        out.push(dir > 0 ? [n - 1 - y, x] : [y, n - 1 - x]);
    }
    return out;
}

function fits(cells, px, py) {
    for (var i = 0; i < cells.length; i++) {
        var x = px + cells[i][0], y = py + cells[i][1];
        if (x < 0 || x >= COLS || y >= ROWS) return false;
        if (y >= 0 && field[y * COLS + x] !== 0) return false;
    }
    return true;
}

function start(lvl) {
    newField();
    bag = [];
    score = 0; lines = 0; startLevel = lvl; level = lvl; over = false;
    nextId = takeFromBag();
    spawn();
}

function spawn() {
    var id = nextId;
    nextId = takeFromBag();
    var s = SHAPES[id];
    cur = { id: id, n: s.n, cells: cellsOf(id), x: s.n === 2 ? 4 : 3, y: id === 1 ? -1 : 0 };
    if (!fits(cur.cells, cur.x, cur.y)) { over = true; return false; }
    return true;
}

function move(dx) {
    if (!cur || !fits(cur.cells, cur.x + dx, cur.y)) return false;
    cur.x += dx; return true;
}

function rotate(dir) {
    if (!cur || cur.id === 2) return false;
    var r = rotated(cur.cells, cur.n, dir);
    for (var k = 0; k < KICKS.length; k++) {
        if (fits(r, cur.x + KICKS[k][0], cur.y + KICKS[k][1])) {
            cur.cells = r; cur.x += KICKS[k][0]; cur.y += KICKS[k][1];
            return true;
        }
    }
    return false;
}

function down() {
    if (!cur || !fits(cur.cells, cur.x, cur.y + 1)) return false;
    cur.y += 1; return true;
}

function grounded() { return cur && !fits(cur.cells, cur.x, cur.y + 1); }

function ghostY() {
    if (!cur) return 0;
    var y = cur.y;
    while (fits(cur.cells, cur.x, y + 1)) y++;
    return y;
}

function hardDrop() {
    var n = 0;
    while (down()) n++;
    score += 2 * n;
    return n;
}

// put the piece into the field; returns the list of full rows (not removed yet)
function lock() {
    var above = false;
    for (var i = 0; i < 4; i++) {
        var x = cur.x + cur.cells[i][0], y = cur.y + cur.cells[i][1];
        if (y < 0) above = true; else field[y * COLS + x] = cur.id;
    }
    cur = null;
    if (above) { over = true; return []; }
    var full = [];
    for (var r = 0; r < ROWS; r++) {
        var f = true;
        for (var c = 0; c < COLS; c++) if (field[r * COLS + c] === 0) { f = false; break; }
        if (f) full.push(r);
    }
    return full;
}

function clearRows(full) {
    if (full.length === 0) return;
    var keep = [];
    for (var r = 0; r < ROWS; r++) {
        if (full.indexOf(r) >= 0) continue;
        keep.push(field.slice(r * COLS, (r + 1) * COLS));
    }
    newField();
    var off = ROWS - keep.length;
    for (var k = 0; k < keep.length; k++)
        for (var c = 0; c < COLS; c++) field[(k + off) * COLS + c] = keep[k][c];
    lines += full.length;
    score += LINE_POINTS[full.length] * (level + 1);
    level = Math.max(startLevel, Math.floor(lines / 10));
}

function speed() { return SPEED[Math.min(level, SPEED.length - 1)]; }

// what each of the 200 cells shows: 0 empty, 1..7 piece, -id = ghost of piece
function frame(showGhost, withPiece) {
    var f = field.slice(0);
    if (cur) {
        var i, x, y;
        if (showGhost) {
            var gy = ghostY();
            for (i = 0; i < 4; i++) {
                x = cur.x + cur.cells[i][0]; y = gy + cur.cells[i][1];
                if (y >= 0 && f[y * COLS + x] === 0) f[y * COLS + x] = -cur.id;
            }
        }
        if (withPiece) for (i = 0; i < 4; i++) {
            x = cur.x + cur.cells[i][0]; y = cur.y + cur.cells[i][1];
            if (y >= 0) f[y * COLS + x] = cur.id;
        }
    }
    return f;
}

function nextCells() { return cellsOf(nextId); }
