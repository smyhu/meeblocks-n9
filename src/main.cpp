/*
 * MeeBlocks - falling blocks puzzle for the Nokia N9 (Harmattan), native launcher.
 * Copyright (c) 2026 smyhu. MIT License (see LICENSE).
 * Designed and written by Claude (Anthropic) together with smyhu.
 */
#include <QtGui/QApplication>
#include <QtCore/QProcess>
#include <QtCore/QStringList>
#include <QtCore/QFile>
#include <QtCore/QDir>
#include <QtCore/QDate>
#include <QtCore/QTextStream>
#include <QtDeclarative/QDeclarativeView>
#include <QtDeclarative/QDeclarativeContext>
#include <QtDeclarative/QDeclarativeEngine>
#include "helper.h"

Helper::Helper(QSettings *settings, QObject *parent) : QObject(parent), m_settings(settings), m_saver(0) {}

QVariant Helper::setting(const QString &key, const QVariant &def) { return m_settings->value(key, def); }
void Helper::setSetting(const QString &key, const QVariant &value) { m_settings->setValue(key, value); m_settings->sync(); }

void Helper::keepScreenOn(bool on)
{
    if (on && !m_saver) {
        m_saver = new QSystemScreenSaver(this);
        m_saver->setScreenSaverInhibited(true);
    } else if (!on && m_saver) {
        delete m_saver;          // releases the inhibit
        m_saver = 0;
    }
}

QString Helper::scoresPath() const
{
    return QDir::homePath() + "/.meeblocks/scores.json";
}

QString Helper::loadScores()
{
    QFile f(scoresPath());
    if (!f.open(QIODevice::ReadOnly)) return QString("[]");
    QTextStream in(&f);
    in.setCodec("UTF-8");
    QString s = in.readAll().trimmed();
    return s.isEmpty() ? QString("[]") : s;
}

void Helper::saveScores(const QString &json)
{
    QDir().mkpath(QDir::homePath() + "/.meeblocks");
    QString path = scoresPath();
    QFile f(path + ".tmp");
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) return;
    QTextStream out(&f);
    out.setCodec("UTF-8");
    out << json << "\n";
    out.flush();
    f.close();
    QFile::remove(path);
    QFile::rename(path + ".tmp", path);
}

QString Helper::today() const
{
    return QDate::currentDate().toString("yyyy-MM-dd");
}

QString Helper::language() const
{
    QByteArray env = qgetenv("APP_LANG");
    if (!env.isEmpty()) return QString::fromLatin1(env);
    QProcess p;
    p.start("/usr/bin/gconftool-2", QStringList() << "-g" << "/meegotouch/i18n/language");
    if (p.waitForFinished(2000)) {
        QString l = QString::fromLatin1(p.readAllStandardOutput()).trimmed();
        if (!l.isEmpty()) return l;
    }
    return QString::fromLatin1(qgetenv("LANG"));
}

int main(int argc, char **argv)
{
    QApplication app(argc, argv);
    app.setApplicationName(APP_NAME);
    QString base = "/opt/" APP_NAME "/qml/";
    QByteArray dir = qgetenv("APP_QML");
    if (!dir.isEmpty()) base = QString::fromLatin1(dir);

    QSettings settings(APP_NAME, APP_NAME);
    Helper helper(&settings);
    QDeclarativeView view;
    view.rootContext()->setContextProperty("helper", &helper);
    QObject::connect(view.engine(), SIGNAL(quit()), &app, SLOT(quit()));
    // N9 performance: opaque full-viewport updates suit the meego GL graphics system
    view.setAttribute(Qt::WA_OpaquePaintEvent);
    view.setAttribute(Qt::WA_NoSystemBackground);
    view.viewport()->setAttribute(Qt::WA_OpaquePaintEvent);
    view.viewport()->setAttribute(Qt::WA_NoSystemBackground);
    view.setViewportUpdateMode(QGraphicsView::FullViewportUpdate);
    view.setSource(QUrl::fromLocalFile(base + "main.qml"));
    view.showFullScreen();
    int r = app.exec();
    helper.keepScreenOn(false);
    return r;
}
