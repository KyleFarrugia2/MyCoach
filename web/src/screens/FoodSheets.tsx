import { type ReactNode, useEffect, useMemo, useRef, useState } from "react";
import { type Day, today } from "../core/dates";
import {
  type FoodItem,
  type MacroGrams,
  MEASUREMENT_STATES,
  MeasurementLabel,
  type MealSlot,
  type MeasurementState,
  hasBannedAllergen,
  mealName,
  mealSlots,
  scaleFood,
  uuid,
} from "../core/models";
import { OPEN_FOOD_FACTS_ATTRIBUTION, blankScannedFood, lookupBarcode } from "../engines/barcode";
import { searchFoods } from "../engines/foodCatalog";
import { parseDecimal } from "../engines/units";
import { actions, customFoodByBarcode, getState, isTrainingDay, useApp } from "../state/store";
import { BarcodeScanner } from "../ui/BarcodeScanner";
import { Button, Card, EmptyState, FoodRow, Icon, NumberInput, Sheet, Toggle, toast } from "../ui/kit";

/** Search the catalog (custom foods first). Used for logging and for meal-plan swaps. */
export function FoodPicker({
  title,
  onPick,
  onClose,
  hideAllergens,
  placeholder = "Search chicken, rice, yogurt…",
}: {
  title: string;
  onPick: (food: FoodItem) => void;
  onClose: () => void;
  hideAllergens?: boolean;
  placeholder?: string;
}) {
  const s = useApp();
  const [query, setQuery] = useState("");
  const [debounced, setDebounced] = useState("");
  const [creating, setCreating] = useState(false);
  const [scanning, setScanning] = useState(false);
  useEffect(() => {
    const t = setTimeout(() => setDebounced(query), 200);
    return () => clearTimeout(t);
  }, [query]);
  const banned = s.profile.allergies;
  const results = useMemo(() => {
    const all = searchFoods(debounced, s.customFoods);
    return hideAllergens ? all.filter((f) => !hasBannedAllergen(f, banned)) : all;
  }, [debounced, s.customFoods, hideAllergens, banned]);

  return (
    <Sheet title={title} full onClose={onClose}>
      <div className="row" style={{ position: "relative" }}>
        <span style={{ position: "absolute", left: 12, color: "var(--text-2)", display: "flex" }}>
          <Icon name="search" size={18} />
        </span>
        <input
          className="input"
          style={{ paddingLeft: 38 }}
          type="search"
          enterKeyHint="search"
          placeholder={placeholder}
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
      </div>
      <div className="grid-2">
        <button className="btn btn-secondary" style={{ minHeight: 46, fontSize: 15 }} onClick={() => setScanning(true)}>
          <Icon name="barcode" size={18} /> Scan Barcode
        </button>
        <button className="btn btn-secondary" style={{ minHeight: 46, fontSize: 15 }} onClick={() => setCreating(true)}>
          <Icon name="plus" size={18} /> Create Food
        </button>
      </div>
      {results.length === 0 ? (
        <EmptyState icon="search" title="No foods found" message="Try another name, or create a custom food." />
      ) : (
        <div className="list">
          {results.map((food) => (
            <FoodRow
              key={food.id}
              food={food}
              chevron
              onClick={() => onPick(food)}
              trailing={
                hasBannedAllergen(food, banned) ? (
                  <span className="badge warn" title="Conflicts with your allergy settings">
                    Allergen
                  </span>
                ) : undefined
              }
            />
          ))}
        </div>
      )}
      {creating && (
        <CustomFoodEditor
          onClose={() => setCreating(false)}
          onSave={(food) => {
            actions.saveCustomFood(food);
            setCreating(false);
            onPick(food);
          }}
        />
      )}
      {scanning && (
        <ScanFoodFlow
          onClose={() => setScanning(false)}
          onFood={(food) => {
            setScanning(false);
            onPick(food);
          }}
        />
      )}
    </Sheet>
  );
}

function preview(food: FoodItem, amount: number, servings: boolean): { calories: number; macros: MacroGrams } | undefined {
  if (!(amount > 0)) return undefined;
  if (servings) {
    return {
      calories: (food.calories ?? 0) * amount,
      macros: {
        protein: (food.proteinGrams ?? 0) * amount,
        carbohydrates: (food.carbohydrateGrams ?? 0) * amount,
        fat: (food.fatGrams ?? 0) * amount,
      },
    };
  }
  return scaleFood(food, amount);
}

export function LogFoodSheet({
  food,
  slot: initialSlot,
  day = today(),
  chooseSlot,
  onDone,
  onBack,
}: {
  food: FoodItem;
  slot?: MealSlot;
  day?: Day;
  /** Show a meal picker (used when logging from the Foods tab). */
  chooseSlot?: boolean;
  onDone: () => void;
  onBack: () => void;
}) {
  const s = useApp();
  const slots = mealSlots(isTrainingDay(s, day));
  const [slot, setSlot] = useState<MealSlot>(initialSlot ?? slots[0]);
  const gramScalable = food.servingGrams !== undefined && food.servingGrams > 0;
  const [servings, setServings] = useState(!gramScalable);
  const [amountText, setAmountText] = useState(gramScalable ? String(food.servingGrams) : "1");
  const amount = parseDecimal(amountText) ?? 0;
  const p = preview(food, amount, servings);
  const allergen = hasBannedAllergen(food, s.profile.allergies);

  return (
    <Sheet title="Log Food" onClose={onBack}>
      <div className="list">
        <FoodRow food={food} />
      </div>
      {allergen && (
        <div className="banner warn">
          <Icon name="warning" size={18} />
          <span>This food contains an allergen from your profile.</span>
        </div>
      )}
      {chooseSlot && (
        <label className="field">
          <span>Meal</span>
          <select className="input" value={slot} onChange={(e) => setSlot(e.target.value as MealSlot)}>
            {slots.map((sl) => (
              <option key={sl} value={sl}>
                {mealName(s.preferences, sl)}
              </option>
            ))}
          </select>
        </label>
      )}
      <div className="list">
        {gramScalable && (
          <Toggle
            label="Log as servings"
            checked={servings}
            onChange={(v) => {
              setServings(v);
              setAmountText(v ? "1" : String(food.servingGrams));
            }}
          />
        )}
        <div className="list-row">
          <span className="grow">{servings ? `Servings (${food.servingDescription})` : "Grams"}</span>
          <div style={{ width: 120 }}>
            <NumberInput value={amountText} onChange={setAmountText} ariaLabel={servings ? "Servings" : "Grams"} />
          </div>
        </div>
      </div>
      {p && (
        <Card className="tight">
          {(
            [
              ["Calories", `${Math.round(p.calories)} kcal`],
              ["Protein", `${Math.round(p.macros.protein)} g`],
              ["Carbs", `${Math.round(p.macros.carbohydrates)} g`],
              ["Fat", `${Math.round(p.macros.fat)} g`],
            ] as const
          ).map(([k, v]) => (
            <div key={k} className="row-between">
              <span className="muted">{k}</span>
              <span className="num">{v}</span>
            </div>
          ))}
        </Card>
      )}
      <Button
        disabled={!p}
        onClick={() => {
          if (!p) return;
          actions.logFood(food, amount, servings, slot, day, p.calories, p.macros);
          toast(`Added to ${mealName(s.preferences, slot)}`);
          onDone();
        }}
      >
        Add to {mealName(s.preferences, slot)}
      </Button>
    </Sheet>
  );
}

/** Search → amount flow for adding a food to a diary meal. */
export function AddFoodFlow({ slot, day, onClose }: { slot: MealSlot; day: Day; onClose: () => void }) {
  const [food, setFood] = useState<FoodItem | null>(null);
  return (
    <>
      <FoodPicker title="Add Food" onPick={setFood} onClose={onClose} />
      {food && <LogFoodSheet food={food} slot={slot} day={day} onBack={() => setFood(null)} onDone={onClose} />}
    </>
  );
}

const fmt0 = (n?: number) => (n === undefined ? "" : String(Math.round(n)));
const fmt1 = (n?: number) => (n === undefined ? "" : String(Math.round(n * 10) / 10));

export function CustomFoodEditor({
  existing,
  prefill,
  notice,
  title,
  onSave,
  onClose,
  onDelete,
}: {
  existing?: FoodItem;
  /** Values to start from for a *new* food (e.g. a scanned product) — saved with its id and barcode. */
  prefill?: FoodItem;
  notice?: ReactNode;
  title?: string;
  onSave: (food: FoodItem) => void;
  onClose: () => void;
  onDelete?: () => void;
}) {
  const base = existing ?? prefill;
  const [name, setName] = useState(base?.name ?? "");
  const [brand, setBrand] = useState(base?.brand ?? "");
  const [servingDescription, setServingDescription] = useState(base?.servingDescription ?? "100 g");
  const [servingGrams, setServingGrams] = useState(base ? fmt0(base.servingGrams) : "100");
  const [calories, setCalories] = useState(fmt0(base?.calories));
  const [protein, setProtein] = useState(fmt1(base?.proteinGrams));
  const [carbs, setCarbs] = useState(fmt1(base?.carbohydrateGrams));
  const [fat, setFat] = useState(fmt1(base?.fatGrams));
  const [fibre, setFibre] = useState(fmt1(base?.fibreGrams));
  const [state, setState] = useState<MeasurementState>(base?.measurementState ?? "prepared");

  const canSave = name.trim().length > 0 && parseDecimal(calories) !== undefined;

  function save() {
    onSave({
      id: base?.id ?? uuid(),
      name: name.trim(),
      brand: brand.trim() || undefined,
      source: base?.barcode ? "barcode" : "customUser",
      barcode: base?.barcode,
      servingDescription: servingDescription.trim() || "1 serving",
      servingGrams: parseDecimal(servingGrams),
      calories: parseDecimal(calories),
      proteinGrams: parseDecimal(protein) ?? 0,
      carbohydrateGrams: parseDecimal(carbs) ?? 0,
      fatGrams: parseDecimal(fat) ?? 0,
      fibreGrams: parseDecimal(fibre),
      measurementState: state,
      isCustom: true,
      isVerified: false,
      allergenTags: base?.allergenTags ?? [],
      isFavorite: base?.isFavorite ?? false,
    });
  }

  const num = (label: string, value: string, set: (v: string) => void) => (
    <label className="field">
      <span>{label}</span>
      <NumberInput value={value} onChange={set} ariaLabel={label} />
    </label>
  );

  return (
    <Sheet
      title={title ?? (existing ? "Edit Nutrition" : "Create Food")}
      full
      onClose={onClose}
      right={
        <button className="link-btn" disabled={!canSave} style={{ opacity: canSave ? 1 : 0.4 }} onClick={save}>
          Save
        </button>
      }
    >
      {notice && (
        <div className="banner">
          <Icon name="info" size={18} />
          <span>{notice}</span>
        </div>
      )}
      {base?.barcode && (
        <div className="row caption">
          <Icon name="barcode" size={16} /> Barcode {base.barcode}
        </div>
      )}
      <p className="section-title">Identity</p>
      <label className="field">
        <span>Food name</span>
        <input className="input" value={name} onChange={(e) => setName(e.target.value)} />
      </label>
      <label className="field">
        <span>Brand (optional)</span>
        <input className="input" value={brand} onChange={(e) => setBrand(e.target.value)} />
      </label>
      <label className="field">
        <span>Measurement</span>
        <select className="input" value={state} onChange={(e) => setState(e.target.value as MeasurementState)}>
          {MEASUREMENT_STATES.map((m) => (
            <option key={m} value={m}>
              {MeasurementLabel[m]}
            </option>
          ))}
        </select>
      </label>
      <div className="grid-2">
        <label className="field">
          <span>Serving description</span>
          <input className="input" value={servingDescription} onChange={(e) => setServingDescription(e.target.value)} />
        </label>
        {num("Serving grams", servingGrams, setServingGrams)}
      </div>
      <p className="section-title">Nutrition (per serving)</p>
      <div className="grid-2">
        {num("Calories", calories, setCalories)}
        {num("Protein (g)", protein, setProtein)}
        {num("Carbs (g)", carbs, setCarbs)}
        {num("Fat (g)", fat, setFat)}
        {num("Fibre (g, optional)", fibre, setFibre)}
      </div>
      <p className="caption">Saved as your custom food. Meal plan calculations will use these values.</p>
      <Button disabled={!canSave} onClick={save}>
        Save Food
      </Button>
      {onDelete && (
        <Button variant="danger" onClick={onDelete}>
          Delete Food
        </Button>
      )}
    </Sheet>
  );
}

type ScanStage =
  | { kind: "scan" }
  | { kind: "lookup"; code: string }
  | { kind: "review"; food: FoodItem; notice: string };

/**
 * Scan → look up (My Foods first, then Open Food Facts) → let the user check the label values → save.
 * Unknown products open a blank editor tied to the barcode, so the next scan finds them instantly offline.
 */
export function ScanFoodFlow({ onFood, onClose }: { onFood: (food: FoodItem) => void; onClose: () => void }) {
  const [stage, setStage] = useState<ScanStage>({ kind: "scan" });
  const abort = useRef<AbortController | null>(null);
  useEffect(() => () => abort.current?.abort(), []);

  async function handle(code: string) {
    const local = customFoodByBarcode(getState(), code);
    if (local) {
      toast("Found in My Foods");
      onFood(local);
      return;
    }
    setStage({ kind: "lookup", code });
    abort.current = new AbortController();
    try {
      const r = await lookupBarcode(code, fetch, abort.current.signal);
      if (r.status === "found") {
        setStage({
          kind: "review",
          food: r.product.food,
          notice: r.product.complete
            ? OPEN_FOOD_FACTS_ATTRIBUTION
            : "Some nutrition values are missing from the database. Fill them in from the label (per 100 g).",
        });
      } else {
        setStage({
          kind: "review",
          food: blankScannedFood(code),
          notice:
            r.status === "notFound"
              ? "This product isn't in the database yet. Enter the nutrition from the label (per 100 g). Next time it scans instantly."
              : r.message,
        });
      }
    } catch {
      /* aborted — sheet closed */
    }
  }

  if (stage.kind === "scan") return <BarcodeScanner onDetected={handle} onClose={onClose} />;
  if (stage.kind === "lookup") {
    return (
      <Sheet title="Looking Up" onClose={onClose}>
        <div className="empty">
          <Icon name="barcode" />
          <h3 className="headline">Finding {stage.code}…</h3>
          <p className="sub">Searching the Open Food Facts product database.</p>
        </div>
      </Sheet>
    );
  }
  return (
    <CustomFoodEditor
      prefill={stage.food}
      notice={stage.notice}
      title="Check Nutrition"
      onClose={onClose}
      onSave={(food) => {
        actions.saveCustomFood(food);
        toast(`${food.name} saved to My Foods`);
        onFood(food);
      }}
    />
  );
}
