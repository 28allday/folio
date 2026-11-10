#pragma once

#include <QObject>
#include <QString>
#include <QStringList>

typedef struct _GMountOperation GMountOperation;
typedef struct _GFile GFile;

// Mounts remote locations (a tailnet machine over SFTP) through GIO, the way
// Nautilus does, so they land under GVfs where every app can see them. GVfs
// asks questions while mounting: whether to trust a machine's host key the
// first time, a password when keys don't work. Those come here as signals
// for the window to put to the user, instead of dying silently as they do
// under `gio mount` with no terminal to ask in.
class Mounter : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool asking READ asking NOTIFY askingChanged)
    Q_PROPERTY(QString prompt READ prompt NOTIFY askingChanged)
    Q_PROPERTY(QStringList choices READ choices NOTIFY askingChanged)
    Q_PROPERTY(bool wantsPassword READ wantsPassword NOTIFY askingChanged)
    Q_PROPERTY(QString user READ user NOTIFY askingChanged)

public:
    explicit Mounter(QObject *parent = nullptr);
    ~Mounter() override;

    bool busy() const { return m_operation != nullptr; }
    bool asking() const { return m_asking; }
    QString prompt() const { return m_prompt; }
    QStringList choices() const { return m_choices; }
    bool wantsPassword() const { return m_wantsPassword; }
    QString user() const { return m_user; }

    // Mounts the location; `mounted` carries its local GVfs path. With
    // `trustNewHost`, a machine seen for the first time is accepted without
    // asking (for tailnet machines, whose identity Tailscale has already
    // checked).
    void mount(const QString &uri, bool trustNewHost = false);

    // The user's answer to a question, by choice index.
    Q_INVOKABLE void choose(int choice);
    // The user's answer to a password request; remembered for this session
    // only, never written to a keyring without asking.
    Q_INVOKABLE void providePassword(const QString &user, const QString &password);
    // Closes the question and abandons the mount.
    Q_INVOKABLE void cancel();

signals:
    void askingChanged();
    void mounted(const QString &uri, const QString &path);
    void failed(const QString &uri, const QString &error);

private:
    // GIO's C callbacks, in mounter.cpp.
    friend struct MounterCallbacks;
    void setAsking(bool asking);
    void finish();

    GMountOperation *m_operation = nullptr;
    GFile *m_file = nullptr;
    QString m_uri;
    bool m_trustNewHost = false;
    bool m_asking = false;
    QString m_prompt;
    QStringList m_choices;
    bool m_wantsPassword = false;
    QString m_user;
};
