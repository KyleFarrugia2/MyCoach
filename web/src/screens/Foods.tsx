import { useEffect, useMemo, useState } from "react";
import { type FoodItem, FoodAllergyLabel, MeasurementLabel, foodSubtitle, hasBannedAllergen, nutritionPerGram } from "../core/models";
import { searchFoods } from "../engines/foodCatalog";
import { actions, useApp } from "../state/store";
import { Button, Card, EmptyState, FoodRow, Icon, Segmented, Sheet, confirmDialog, toast } from "../ui/kit";
import { CustomFoodEditor, LogFoodSheet, ScanFoodFlow } from "./FoodSheets";

type Filter = "all" | "mine" | "scanned" | "generic";

const FILTERS: { value: Filter; label: string }[] = [
  { value: "all", label: "All" },
  { value: "mine", label: "My Foods" },
  { value: "scanned", label: "Scanned" },
  { value: "generic", label: "Generic" },
];

function matchesFilter(f: FoodItem, filter: Filter): boolean {
  switch (filter) {
    case "all":
      return true;
    case "mine":
      return f.isCustom;
    case "scanned":
      return !!f.barcode;
    case "generic":
      return f.source === "bundledGeneric";
  }
}

/** Every food the app knows: the user's own, scanned products, and the bundled generic database. */
export function Foods() {
  const s = useApp();
  const [query, setQuery] = useState("");
  const [debounced, setDebounced] = useState("");
  const [filter, setFilter] = useState<Filter>("all");
  const [detail, setDetail] = useState<FoodItem | null>(null);
  const [scanning, setScanning] = useState(false);
  const [creating, setCreating] = useState(false);

  useEffect(() => {
    const t = setTimeout(() => setDebounced(query), 150);
    return () => clearTimeout(t);
  }, [query]);

  const foods = useMemo(
    () => searchFoods(debounced, s.customFoods).filter((f) => matchesFilter(f, filter)),
    [debounced, s.customFoods, filter],
  );
  const mine = foods.filter((f) => f.isCustom);
  const generic = foods.filter((f) => !f.isCustom);

  // Keep the open detail sheet in sync if the food is edited.
  const current = detail ? (s.customFoods.find((f) => f.id === detail.id) ?? detail) : null;

  return (
    <div className="screen">
      <div className="screen-header">
        <h1 className="screen-title">Foods</h1>
        <div className="row">
          <button className="icon-btn" aria-label="Scan barcode" onClick={() => setScanning(true)}>
            <Icon name="barcode" />
          </button>
          <button className="icon-btn" aria-label="Create food" onClick={() => setCreating(true)}>
            <Icon name="plus" />
          </button>
        </div>
      </div>

      <Button onClick={() => setScanning(true)}>
        <Icon name="barcode" /> Scan a Barcode
      </Button>

      <div className="row" style={{ position: "relative" }}>
        <span style={{ position: "absolute", left: 12, color: "var(--text-2)", display: "flex" }}>
          <Icon name="search" size={18} />
        </span>
        <input
          className="input"
          style={{ paddingLeft: 38 }}
          type="search"
          enterKeyHint="search"
          placeholder="Search foods, brands or barcodes"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
      </div>
      <Segmented options={FILTERS} value={filter} onChange={setFilter} />
      <span className="caption" style={{ padding: "0 4px" }}>
        {foods.length} {foods.length === 1 ? "food" : "foods"}
      </span>

      {foods.length === 0 ? (
        <Card>
          <EmptyState
            icon={filter === "scanned" ? "barcode" : "search"}
            title={filter === "scanned" && !query ? "No scanned foods yet" : "No foods found"}
            message={
              filter === "scanned" && !query
                ? "Scan a packaged food's barcode to add it with its label nutrition."
                : "Try another search, scan a barcode, or create a food."
            }
            actionTitle="Scan a Barcode"
            onAction={() => setScanning(true)}
          />
        </Card>
      ) : (
        <>
          {mine.length > 0 && (
            <div className="stack-sm">
              <p className="section-title">My Foods ({mine.length})</p>
              <div className="list">
                {mine.map((f) => (
                  <FoodRow key={f.id} food={f} chevron onClick={() => setDetail(f)} trailing={f.barcode ? <Icon name="barcode" size={16} className="muted" /> : undefined} />
                ))}
              </div>
            </div>
          )}
          {generic.length > 0 && (
            <div className="stack-sm">
              <p className="section-title">Generic Database ({generic.length})</p>
              <div className="list">
                {generic.map((f) => (
                  <FoodRow key={f.id} food={f} chevron onClick={() => setDetail(f)} />
                ))}
              </div>
            </div>
          )}
        </>
      )}

      {current && <FoodDetail food={current} onClose={() => setDetail(null)} />}
      {scanning && (
        <ScanFoodFlow
          onClose={() => setScanning(false)}
          onFood={(food) => {
            setScanning(false);
            setDetail(food);
          }}
        />
      )}
      {creating && (
        <CustomFoodEditor
          onClose={() => setCreating(false)}
          onSave={(food) => {
            actions.saveCustomFood(food);
            setCreating(false);
            toast(`${food.name} saved to My Foods`);
          }}
        />
      )}
    </div>
  );
}

function FoodDetail({ food, onClose }: { food: FoodItem; onClose: () => void }) {
  const s = useApp();
  const [logging, setLogging] = useState(false);
  const [editing, setEditing] = useState(false);
  // Second column only when the serving isn't already 100 g.
  const per = food.servingGrams === 100 ? undefined : nutritionPerGram(food);
  const allergens = food.allergenTags.filter((a) => a !== "none");
  const conflict = hasBannedAllergen(food, s.profile.allergies);
  const fmt = (v?: number, unit = "g") => (v === undefined ? "—" : `${Math.round(v * 10) / 10} ${unit}`);

  const rows: [string, number | undefined, number | undefined, string][] = [
    ["Calories", food.calories, per ? per.calories * 100 : undefined, "kcal"],
    ["Protein", food.proteinGrams, per ? per.protein * 100 : undefined, "g"],
    ["Carbs", food.carbohydrateGrams, per ? per.carbs * 100 : undefined, "g"],
    ["Fat", food.fatGrams, per ? per.fat * 100 : undefined, "g"],
    ["Fibre", food.fibreGrams, per && food.fibreGrams !== undefined && food.servingGrams ? (food.fibreGrams / food.servingGrams) * 100 : undefined, "g"],
  ];

  return (
    <Sheet title={food.name || "Food"} onClose={onClose}>
      <div className="stack-sm">
        <span className="title2">{food.name}</span>
        <span className="sub">
          {foodSubtitle(food)} · {MeasurementLabel[food.measurementState]}
        </span>
        {food.barcode && (
          <span className="caption row">
            <Icon name="barcode" size={14} /> {food.barcode}
          </span>
        )}
      </div>

      {conflict && (
        <div className="banner warn">
          <Icon name="warning" size={18} />
          <span>Contains an allergen from your profile.</span>
        </div>
      )}

      <div className="list">
        <div className="list-row caption">
          <span className="grow">Nutrition</span>
          <span style={{ width: 90, textAlign: "right" }}>Per {food.servingDescription}</span>
          {per && <span style={{ width: 70, textAlign: "right" }}>Per 100 g</span>}
        </div>
        {rows.map(([label, serving, per100, unit]) => (
          <div key={label} className="list-row">
            <span className="grow">{label}</span>
            <span className="num" style={{ width: 90, textAlign: "right", fontSize: 15 }}>
              {fmt(serving, unit)}
            </span>
            {per && (
              <span className="num muted" style={{ width: 70, textAlign: "right", fontSize: 15 }}>
                {fmt(per100, unit)}
              </span>
            )}
          </div>
        ))}
      </div>

      {allergens.length > 0 && (
        <p className="caption">Allergens: {allergens.map((a) => FoodAllergyLabel[a]).join(", ")}</p>
      )}
      {food.source === "barcode" && <p className="caption2">Product data from Open Food Facts (ODbL), checked by you when saved.</p>}

      <Button onClick={() => setLogging(true)}>Log This Food</Button>
      {food.isCustom && (
        <>
          <Button variant="secondary" onClick={() => setEditing(true)}>
            Edit Nutrition
          </Button>
          <Button
            variant="danger"
            onClick={async () => {
              if (await confirmDialog({ title: `Delete ${food.name}?`, message: "Past food-log entries keep their values.", confirm: "Delete", destructive: true })) {
                actions.deleteCustomFood(food.id);
                onClose();
              }
            }}
          >
            Delete Food
          </Button>
        </>
      )}

      {logging && <LogFoodSheet food={food} chooseSlot onBack={() => setLogging(false)} onDone={() => setLogging(false)} />}
      {editing && (
        <CustomFoodEditor
          existing={food}
          onClose={() => setEditing(false)}
          onSave={(f) => {
            actions.saveCustomFood(f);
            setEditing(false);
          }}
        />
      )}
    </Sheet>
  );
}
