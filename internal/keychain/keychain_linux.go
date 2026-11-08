package keychain

import (
	"errors"
	"slices"
	"strings"

	"github.com/godbus/dbus/v5"
)

// noKeychain is ErrNoKeychain's text on Linux: the Secret Service runs but
// names no default collection (KeePassXC with no group exposed to it, or a
// keyring whose login collection was deleted).
const noKeychain = "your keyring has no default collection to keep Nushi's tokens in: make one in its app (Passwords and Keys, or KeePassXC's Secret Service settings), then try again"

// Set stores secret for account in the default collection, replacing an
// item of the same service and account there; label is what the keyring's
// app shows. A locked collection is unlocked first, which may show the
// keyring's prompt: the user has just given the secret. A copy left in
// another, unlocked collection (one that was the default before) is then
// removed, so no old token stays behind; one in a locked collection is
// left without a prompt, as Get prefers the default collection's.
func (k Keychain) Set(account, label string, secret []byte) error {
	c, err := k.connect(ErrLocked)
	if err != nil {
		return err
	}
	defer c.close()
	coll, err := c.defaultCollection()
	if err != nil {
		return err
	}
	if coll == noObject {
		return k.failed(serviceIface+".ReadAlias", errors.New("no default collection"), ErrNoKeychain)
	}
	if _, err := c.unlock([]dbus.ObjectPath{coll}, true); err != nil {
		return err
	}
	session, err := c.openSession()
	if err != nil {
		return err
	}
	props := map[string]dbus.Variant{
		itemIface + ".Label":      dbus.MakeVariant(label),
		itemIface + ".Attributes": dbus.MakeVariant(k.attributes(account)),
	}
	var item, prompt dbus.ObjectPath
	value := secretOf(session, secret)
	if err := c.call(coll, collectionIface+".CreateItem", []any{&item, &prompt}, props, value, true); err != nil {
		return err
	}
	if prompt != noObject {
		if _, err := c.prompt(collectionIface+".CreateItem", prompt); err != nil {
			return err
		}
	}
	c.removeElsewhere(account, coll)
	return nil
}

// Get reads account's secret, from the item Set wrote when there are
// several (below). An item in a locked collection needs it unlocked: with
// prompt the keyring asks the user for its password (and Get waits for the
// answer); without, that is ErrNeedsOK.
func (k Keychain) Get(account string, prompt bool) ([]byte, error) {
	c, err := k.connect(ErrNeedsOK)
	if err != nil {
		return nil, err
	}
	defer c.close()
	item, err := c.pick(account, prompt)
	if err != nil {
		return nil, err
	}
	session, err := c.openSession()
	if err != nil {
		return nil, err
	}
	var s secret
	if err := c.call(item, itemIface+".GetSecret", []any{&s}, session); err != nil {
		return nil, err
	}
	return s.Value, nil
}

// Delete removes account's items in every collection; none is no error. A
// locked collection is unlocked first, which may show the keyring's prompt
// (the user is removing what the item is for).
func (k Keychain) Delete(account string) error {
	c, err := k.connect(ErrLocked)
	if err != nil {
		return err
	}
	defer c.close()
	unlocked, locked, err := c.search(account)
	if err != nil {
		return err
	}
	if len(locked) > 0 {
		more, err := c.unlock(locked, true)
		if err != nil {
			return err
		}
		unlocked = append(unlocked, more...)
	}
	for _, item := range unlocked {
		var prompt dbus.ObjectPath
		if err := c.call(item, itemIface+".Delete", []any{&prompt}); err != nil {
			if errors.Is(err, ErrNotFound) {
				continue
			}
			return err
		}
		if prompt != noObject {
			if _, err := c.prompt(itemIface+".Delete", prompt); err != nil {
				return err
			}
		}
	}
	return nil
}

// attributes are what an item is found by: the Mac's service and account.
func (k Keychain) attributes(account string) map[string]string {
	return map[string]string{"service": k.Service, "account": account}
}

// pick is the one of account's items Get reads, unlocked (with the
// keyring's prompt only when mayPrompt). Several are copies in other
// collections, left when the default alias moved: the default collection's
// is the one Set wrote last, so it wins even when locked, and an unlocked
// item wins over a locked one in the same place, so nothing is unlocked
// that needn't be.
func (c *conn) pick(account string, mayPrompt bool) (dbus.ObjectPath, error) {
	unlocked, locked, err := c.search(account)
	if err != nil {
		return "", err
	}
	all := slices.Concat(unlocked, locked)
	if len(all) == 0 {
		return "", &Error{Call: serviceIface + ".SearchItems", Msg: "no such item", Kind: ErrNotFound}
	}
	coll := noObject
	if len(all) > 1 {
		if coll, err = c.defaultCollection(); err != nil {
			return "", err
		}
	}
	// rank orders the items: the default collection's unlocked, its
	// locked, another's unlocked, another's locked.
	rank := func(i int) int {
		r := 0
		if !inCollection(all[i], coll) {
			r += 2
		}
		if i >= len(unlocked) {
			r++
		}
		return r
	}
	best := 0
	for i := range all {
		if rank(i) < rank(best) {
			best = i
		}
	}
	if best >= len(unlocked) {
		if _, err := c.unlock(all[best:best+1], mayPrompt); err != nil {
			return "", err
		}
	}
	return all[best], nil
}

// removeElsewhere deletes account's unlocked items outside coll, the
// default collection Set just wrote to. It is tidying, never a prompt: a
// failure is logged (by call) and skipped.
func (c *conn) removeElsewhere(account string, coll dbus.ObjectPath) {
	unlocked, _, err := c.search(account)
	if err != nil {
		return
	}
	for _, item := range unlocked {
		if inCollection(item, coll) {
			continue
		}
		var prompt dbus.ObjectPath
		if err := c.call(item, itemIface+".Delete", []any{&prompt}); err == nil && prompt != noObject {
			_ = c.call(prompt, promptIface+".Dismiss", nil)
		}
	}
}

// inCollection says whether item is coll's: the Secret Service's items
// live below their collection's path (/org/freedesktop/secrets/collection/
// login/1 is login's).
func inCollection(item, coll dbus.ObjectPath) bool {
	return coll != noObject && strings.HasPrefix(string(item), string(coll)+"/")
}
