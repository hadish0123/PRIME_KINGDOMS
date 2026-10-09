export async function grantXP(db, profile, source, eventId, requested, now) {
  let amount = Math.min(100000, Math.max(0, Math.floor(requested)));
  if (source === 'training' || source === 'research' || source==='battle') {
    const cap = Number((await db.query('SELECT value FROM kingdom_config WHERE key=$1', [`daily_${source}_xp_cap`])).rows[0].value);
    const used = Number((await db.query("SELECT coalesce(sum(amount),0) AS used FROM kingdom_xp_events WHERE player_id=$1 AND source=$2 AND occurred_at >= date_trunc('day',$3::timestamptz AT TIME ZONE 'UTC') AT TIME ZONE 'UTC'", [profile.player_id, source, now])).rows[0].used);
    amount = Math.max(0, Math.min(amount, cap - used));
  }
  const inserted = await db.query('INSERT INTO kingdom_xp_events(player_id,source,event_id,amount,occurred_at) VALUES($1,$2,$3,$4,$5) ON CONFLICT DO NOTHING RETURNING amount', [profile.player_id, source, eventId, amount, now]);
  if (!inserted.rows.length) return;
  profile.xp = Math.min(8000000000000000, Number(profile.xp) + amount);
  await db.query('UPDATE kingdoms SET xp=$2 WHERE player_id=$1', [profile.player_id, profile.xp]);
}

export async function progression(db, profile) {
  const levels = (await db.query('SELECT * FROM kingdom_level_requirements ORDER BY level')).rows;
  const qualifies = r => Number(r.cumulative_xp) <= Number(profile.xp) && r.prestige <= profile.prestige && r.conquests <= profile.conquests && r.seasonal_medals <= profile.seasonal_medals && r.ascension_tokens <= profile.ascension_tokens;
  let level = 1;
  for (const r of levels) { if (!qualifies(r)) break; level = r.level; }
  const next = levels.find(r => r.level === level + 1);
  return { level, xp: Number(profile.xp), prestige: profile.prestige, conquests: profile.conquests, seasonalMedals: profile.seasonal_medals, ascensionTokens: profile.ascension_tokens, next: next ? { level: next.level, xp: Number(next.cumulative_xp), prestige: next.prestige, conquests: next.conquests, seasonalMedals: next.seasonal_medals, ascensionTokens: next.ascension_tokens } : null };
}
