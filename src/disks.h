#pragma once

#include <QCoreApplication>
#include <QList>
#include <QMap>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <memory>

// A whole disk (a USB stick, an SD card, an internal drive) as udisks
// describes it, with what's on it gathered from its partitions and whatever
// is unlocked on top of them.
struct Disk {
    // udisks' objects: the disk's own block device, and its drive.
    QString block;
    QString drive;
    QString device;
    // Who it is, not only where: its object path, its drive's Id (maker,
    // model and serial), its size and what's on it. A stick pulled out and
    // another put in takes the same object path, and a card swapped in a
    // reader the same drive, so a disk chosen in a menu is only changed
    // while this still matches.
    QString identity;
    QString vendor, model, label;
    qint64 size = 0;
    QString bus;
    bool removable = false;
    bool canPowerOff = false;
    bool ejectable = false;
    bool readOnly = false;
    bool optical = false;
    // udisks' own guess that it belongs to the computer rather than being
    // a device plugged into it.
    bool hintSystem = false;
    // Part of it makes up another device (an LVM volume group, a RAID
    // array) or is swap in use. Whatever is mounted from those can't be
    // followed back here, so it may hold the system without saying so.
    bool inUse = false;
    // Where anything on it is mounted, and the filesystems mounted there,
    // which have to let go before the disk can be written.
    QStringList mounts;
    QStringList filesystems;
};

// Folio's way to udisks2: listing disks and the few changes it makes to
// them. Every change goes through udisks, so polkit decides who may make it
// and udisks refuses what's in use. Tests stand a fake in for it, which
// writes into a file instead of a device. Each change returns an empty
// string, or a sentence saying why it couldn't be done.
class Disks {
    Q_DECLARE_TR_FUNCTIONS(Disks)

public:
    virtual ~Disks() = default;

    // The one Folio uses: udisks on the system bus, unless something (a
    // test) has put another in its place.
    static std::shared_ptr<Disks> instance();
    static void replace(std::shared_ptr<Disks> disks);

    virtual QList<Disk> list() = 0;
    virtual QString unmount(const QString &filesystem) = 0;
    // A new, empty GPT partition table over the whole disk.
    virtual QString makeTable(const Disk &disk) = 0;
    // One partition filling the table, of the Microsoft basic data type,
    // formatted exFAT with `label`; `partition` is the filesystem made.
    virtual QString addExfat(const Disk &disk, const QString &label, QString *partition) = 0;
    virtual QString mount(const QString &filesystem) = 0;
    // A file descriptor writing to the whole disk, which only udisks may
    // hand out. The caller closes it.
    virtual QString open(const Disk &disk, int *fd) = 0;
    // Lets the disk go for good, so it's safe to pull out.
    virtual QString eject(const Disk &disk) = 0;

    // udisks' objects as GetManagedObjects lists them: object path, then
    // interface (without "org.freedesktop.UDisks2."), then its properties.
    // Object paths and byte strings are plain strings here, MountPoints a
    // string list.
    using Objects = QMap<QString, QMap<QString, QVariantMap>>;
    static QList<Disk> parse(const Objects &objects);

    // Whether a filesystem mounted at `root` is part of the system itself
    // (/, /boot, /home…), which no drive menu may touch.
    static bool isSystemMount(const QString &root);
    static bool holdsSystem(const Disk &disk);

    // How a person knows the disk: its maker and model ("SanDisk Ultra"),
    // or its label, and with its size ("SanDisk Ultra · 32 GB").
    static QString name(const Disk &disk);
    static QString title(const Disk &disk);
    static QString size(qint64 bytes);

    // Whether an image of `imageSize` bytes may be burned onto the disk:
    // only removable disks that can be written, not the system's, and
    // big enough for it.
    enum Fit { Unfit, TooSmall, Fits };
    static Fit fit(const Disk &disk, qint64 imageSize);

    // exFAT keeps at most 11 UTF-16 characters of a label (mkfs.exfat and
    // libblockdev both refuse longer ones).
    static constexpr int labelLimit = 11;
    static bool labelFits(const QString &label) { return label.size() <= labelLimit; }
};
