extends RefCounted
## Explicit CAD identities. Small auxiliary water pieces intentionally use coastal.
const IDS := {
    "3861e9e6-1993-4c9a-9445-ddd4e3b687a2": "lagoon_north",
    "79d2ce03-2e53-4c69-9a13-a18da1838f89": "lagoon_south",
    "a851549b-eb4e-4be2-bfc5-8052291a6c72": "coastal_sea",
    "8540c7bb-0104-46f5-b3e2-24fa8d22424b": "open_sea",
    "65e339ae-787b-45ff-878a-860689777556": "coastal_sea",
    "9bdd169a-e154-438d-8b7f-88774f808433": "coastal_sea",
    "c5268510-5ebe-4a92-bbd0-83c6bcd4ade1": "coastal_sea",
}
const SETTINGS := {
    "lagoon_south": {"shallow": Color("58bcb2"), "deep": Color("287b91"), "absorption": 0.62, "wind": 0.45, "bottom": true},
    "lagoon_north": {"shallow": Color("66c4b3"), "deep": Color("2c8190"), "absorption": 0.52, "wind": 0.35, "bottom": true},
    "coastal_sea": {"shallow": Color("4ab5b5"), "deep": Color("247d9a"), "absorption": 0.85, "wind": 0.80, "bottom": true},
    "open_sea": {"shallow": Color("4ab5b5"), "deep": Color("247d9a"), "absorption": 0.85, "wind": 1.0, "bottom": false},
}

static func profile_for(id: String) -> String:
    if not IDS.has(id):push_warning("Unregistered water ID; coastal fallback: " + id)
    return IDS.get(id, "coastal_sea")
