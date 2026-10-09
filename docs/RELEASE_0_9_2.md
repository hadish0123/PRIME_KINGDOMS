# PRIME KINGDOMS 0.9.2 — Royal Council design candidate

This Android review build replaces the flat strategy interface with a coherent royal design: original realistic ruler portrait, painted resource and navigation icons, architectural previews, beveled gold frames and construction actions. The compact realm header preserves space for the living 3D settlement. The council uses vertical scrolling and wrapping costs, with server-backed requirements and real action callbacks.

Settlement presentation adds bounded residential scenery, instanced trees, photogrammetry rocks, wind-animated wheat for constructed farms and an academy cloister. Architecture follows completed server levels. Unbuilt sites show survey stakes; camera composition shifts smoothly when a council sidebar opens. Residents and production data are preserved.

App/backend version: 0.9.2. Android version code: 16. Engine: Godot 4.7.2, GL Compatibility. No new database migration is required for this design revision. Applied strategy migrations remain immutable.

Required gates: backend checks/unit tests, native PostgreSQL integration, GDScript parsing, account/reconnect/kingdom authority, real GL renders, responsive council geometry, APK export and signature verification. GitHub Actions publishes the versioned test candidate after these gates pass.

This is a design review candidate. Full master production completion, physical Android performance, production signing and Railway rollout require their own verified release gates. This revision does not claim the complete game or production release is final.
