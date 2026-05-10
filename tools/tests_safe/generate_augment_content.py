from __future__ import annotations

import ast
import re
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "docs/superpowers/plans/2026-05-10-full-augment-system-content-manifest.md"
CONTENT_ROOT = ROOT / "data/content/augments"

RARITY_MAP = {
    "银色": "silver",
    "金色": "gold",
    "棱彩": "prismatic",
}


def main() -> None:
    entries = parse_manifest(MANIFEST_PATH.read_text(encoding="utf-8-sig"))
    if len(entries) != 72:
        raise SystemExit(f"expected 72 manifest entries, found {len(entries)}")
    for entry in entries:
        write_tres(entry)
    print(f"generated {len(entries)} augment resources")


def parse_manifest(text: str) -> list[dict[str, Any]]:
    entry_re = re.compile(r"^###\s+(\d+)\.\s+(.+?)\s+\(`([^`]+)`\)\s*$", re.MULTILINE)
    matches = list(entry_re.finditer(text))
    entries: list[dict[str, Any]] = []
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        block = text[match.end() : end]
        fields = parse_fields(block)
        augment_id = match.group(3)
        if fields.get("resource_path") != f"data/content/augments/{fields.get('route_id')}/{augment_id}.tres":
            raise ValueError(f"{augment_id}: resource_path does not match route/id")
        blueprint = parse_blueprint(block)
        trigger_spec = parse_trigger_spec(fields["trigger_spec"])
        entries.append(
            {
                "manifest_index": len(entries) + 1,
                "id": augment_id,
                "display_name": match.group(2),
                "fields": fields,
                "trigger_spec": trigger_spec,
                "effect_spec_blueprint": blueprint,
            }
        )
    return entries


def parse_fields(block: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    current_key = ""
    for raw_line in block.splitlines():
        line = raw_line.rstrip()
        match = re.match(r"^- `([^`]+)`: ?(.*)$", line)
        if match:
            current_key = match.group(1)
            fields[current_key] = strip_backticks(match.group(2).strip())
            continue
        if current_key and line and not line.startswith("```") and not line.startswith("- `test_assertions`"):
            if current_key not in ["effect_spec_blueprint", "test_assertions"]:
                fields[current_key] = (fields[current_key] + "\n" + strip_backticks(line.strip())).strip()
    required = [
        "source_augment_name",
        "source_augment_rarity",
        "route_id",
        "route_label",
        "rarity",
        "max_rank",
        "unique",
        "upgrade_type",
        "trigger",
        "effect",
        "condition",
        "value",
        "synergy_tags",
        "required_tags",
        "excludes_tags",
        "combo_value",
        "fit",
        "risk",
        "why_close",
        "implementation_hint",
        "resource_path",
        "test_owner",
        "checkpoint_priority",
        "trigger_spec",
    ]
    missing = [key for key in required if key not in fields]
    if missing:
        raise ValueError(f"manifest entry missing fields: {missing}")
    return fields


def parse_blueprint(block: str) -> list[dict[str, Any]]:
    match = re.search(r"- `effect_spec_blueprint`:\s*\n\n```gdscript\n(.*?)\n```", block, re.DOTALL)
    if not match:
        raise ValueError("missing effect_spec_blueprint block")
    source = match.group(1)
    source = re.sub(r'(?<!["\w])true(?!["\w])', "True", source)
    source = re.sub(r'(?<!["\w])false(?!["\w])', "False", source)
    source = re.sub(r'(?<!["\w])null(?!["\w])', "None", source)
    value = ast.literal_eval(source)
    if not isinstance(value, list) or not value:
        raise ValueError("effect_spec_blueprint is not a non-empty list")
    return value


def parse_trigger_spec(text: str) -> dict[str, Any]:
    parts: dict[str, str] = {}
    for segment in text.split(";"):
        if "=" not in segment:
            continue
        key, value = segment.split("=", 1)
        parts[key.strip()] = value.strip()
    required_packet_keys: list[str] = []
    required_packet_values: dict[str, str] = {}
    for item in split_csv(parts.get("required_packet_keys", "")):
        if "=" in item:
            key, value = item.split("=", 1)
            required_packet_keys.append(key.strip())
            required_packet_values[key.strip()] = value.strip()
        else:
            required_packet_keys.append(item)
    return {
        "trigger_id": parts.get("trigger_id", ""),
        "signal_names": split_csv(parts.get("signals", "")),
        "required_packet_keys": required_packet_keys,
        "required_packet_values": required_packet_values,
        "synthetic_test": parts.get("synthetic_test", ""),
    }


def write_tres(entry: dict[str, Any]) -> None:
    fields = entry["fields"]
    augment_id = entry["id"]
    route_id = fields["route_id"]
    target = CONTENT_ROOT / route_id / f"{augment_id}.tres"
    target.parent.mkdir(parents=True, exist_ok=True)

    max_rank = int(fields["max_rank"])
    unique = fields["unique"].lower() == "true"
    checkpoint_priority = 0 if fields["checkpoint_priority"] == "none" else int(fields["checkpoint_priority"])
    rarity = RARITY_MAP.get(fields["rarity"], fields["rarity"])
    synergy_tags = split_csv(fields["synergy_tags"])
    required_tags = split_csv(fields["required_tags"])
    excludes_tags = split_csv(fields["excludes_tags"])
    upgrade_type = fields["upgrade_type"]
    risk = fields["risk"]
    manifest_fields = {
        "id": augment_id,
        "display_name": entry["display_name"],
        "source_augment_name": fields["source_augment_name"],
        "source_augment_rarity": fields["source_augment_rarity"],
        "route_id": route_id,
        "route_label": fields["route_label"],
        "rarity": fields["rarity"],
        "normalized_rarity": rarity,
        "max_rank": max_rank,
        "unique": unique,
        "upgrade_type": upgrade_type,
        "trigger": fields["trigger"],
        "effect": fields["effect"],
        "condition": fields["condition"],
        "value": fields["value"],
        "synergy_tags": synergy_tags,
        "required_tags": required_tags,
        "excludes_tags": excludes_tags,
        "combo_value": fields["combo_value"],
        "fit": fields["fit"],
        "risk": risk,
        "why_close": fields["why_close"],
        "implementation_hint": fields["implementation_hint"],
        "resource_path": fields["resource_path"],
        "test_owner": fields["test_owner"],
        "checkpoint_priority": checkpoint_priority,
        "trigger_spec": fields["trigger_spec"],
        "effect_spec_blueprint": entry["effect_spec_blueprint"],
        "is_starter": "启动器" in upgrade_type,
        "is_finisher": "终结器" in upgrade_type,
        "is_high_risk": "代价型" in upgrade_type,
    }
    data = [
        '[gd_resource type="Resource" script_class="AugmentData" load_steps=2 format=3]',
        "",
        '[ext_resource type="Script" path="res://data/resources/augment_data.gd" id="1_aug_data"]',
        "",
        "[resource]",
        'script = ExtResource("1_aug_data")',
        f'id = {gd_value(augment_id)}',
        f'display_name = {gd_value(entry["display_name"])}',
        f'description = {gd_value(fields["effect"])}',
        f'source_augment_name = {gd_value(fields["source_augment_name"])}',
        f'source_augment_rarity = {gd_value(fields["source_augment_rarity"])}',
        f'route_id = {gd_value(route_id)}',
        f'route_label = {gd_value(fields["route_label"])}',
        f'rarity = {gd_value(rarity)}',
        f"max_rank = {max_rank}",
        f"unique = {gd_bool(unique)}",
        f'upgrade_type = {gd_value(upgrade_type)}',
        f'source_trigger = {gd_value(fields["trigger"])}',
        f'effect = {gd_value(fields["effect"])}',
        f'source_condition = {gd_value(fields["condition"])}',
        f'value = {gd_value({"source_text": fields["value"]})}',
        f"synergy_tags = {gd_typed_string_array(synergy_tags)}",
        f"required_tags = {gd_typed_string_array(required_tags)}",
        f"excludes_tags = {gd_typed_string_array(excludes_tags)}",
        "excludes_ids = Array[String]([])",
        f'combo_value = {gd_value(fields["combo_value"])}',
        f'fit = {gd_value(fields["fit"])}',
        f'risk = {gd_value(risk)}',
        f'why_close = {gd_value(fields["why_close"])}',
        f'implementation_hint = {gd_value(fields["implementation_hint"])}',
        "weight = 1.0",
        "min_upgrade_index = 0",
        "max_upgrade_index = -1",
        f'manifest_resource_path = {gd_value(fields["resource_path"])}',
        f'test_owner = {gd_value(fields["test_owner"])}',
        f"checkpoint_priority = {checkpoint_priority}",
        f"manifest_fields = {gd_value(manifest_fields)}",
        f"trigger_spec = {gd_value(entry['trigger_spec'])}",
        f"effect_spec_blueprint = Array[Dictionary]({gd_value(entry['effect_spec_blueprint'])})",
        "",
    ]
    target.write_text("\n".join(data), encoding="utf-8")


def split_csv(value: str) -> list[str]:
    if not value:
        return []
    return [part.strip() for part in value.split(",") if part.strip()]


def strip_backticks(value: str) -> str:
    if value == "``":
        return ""
    if value.startswith("`") and value.endswith("`"):
        return value[1:-1]
    return value


def gd_typed_string_array(values: list[str]) -> str:
    return f"Array[String]({gd_value(values)})"


def gd_bool(value: bool) -> str:
    return "true" if value else "false"


def gd_value(value: Any) -> str:
    if isinstance(value, str):
        return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'
    if isinstance(value, bool):
        return gd_bool(value)
    if value is None:
        return "null"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, list):
        return "[" + ", ".join(gd_value(item) for item in value) + "]"
    if isinstance(value, dict):
        items = []
        for key in sorted(value.keys()):
            items.append(f"{gd_value(str(key))}: {gd_value(value[key])}")
        return "{\n" + ",\n".join(items) + "\n}"
    raise TypeError(f"unsupported value type: {type(value)!r}")


if __name__ == "__main__":
    main()
