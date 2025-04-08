# capacitor-childwindow

Creates child window of a Capacitor app in which an event handler can trap navigation actions

## Install

```bash
npm install capacitor-childwindow
npx cap sync
```

## API

<docgen-index>

* [`open(...)`](#open)
* [`close()`](#close)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

### open(...)

```typescript
open(options: { url: string; }) => Promise<void>
```

Open a URL in an in-app browser

| Param         | Type                          | Description                    |
| ------------- | ----------------------------- | ------------------------------ |
| **`options`** | <code>{ url: string; }</code> | Options for the in-app browser |

--------------------


### close()

```typescript
close() => Promise<void>
```

Close the in-app browser

--------------------

</docgen-api>
