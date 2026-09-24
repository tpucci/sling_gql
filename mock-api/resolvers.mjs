import { GraphQLError, GraphQLScalarType, Kind } from "graphql";
import {
  company,
  rockets,
  launchpads,
  astronauts,
  launches,
  findRocket,
  findLaunchpad,
  findLaunch,
  findAstronaut,
  toggleFavorite as toggleFavoriteData,
  scheduleLaunch as scheduleLaunchData,
  updateLaunchStatus as updateLaunchStatusData,
} from "./data.mjs";

// ---------------------------------------------------------------------------
// DateTime scalar
// ---------------------------------------------------------------------------

function parseIsoDate(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new GraphQLError(`DateTime cannot represent an invalid date: ${value}`);
  }
  return date;
}

export const DateTime = new GraphQLScalarType({
  name: "DateTime",
  description: "ISO-8601 timestamp, e.g. 2024-03-14T13:30:00.000Z",
  serialize(value) {
    const date = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(date.getTime())) {
      throw new GraphQLError(`DateTime cannot serialize invalid date value: ${value}`);
    }
    return date.toISOString();
  },
  parseValue(value) {
    return parseIsoDate(value);
  },
  parseLiteral(ast) {
    if (ast.kind !== Kind.STRING) {
      throw new GraphQLError("DateTime literals must be strings");
    }
    return parseIsoDate(ast.value);
  },
});

// ---------------------------------------------------------------------------
// Filtering / ordering / pagination helpers
// ---------------------------------------------------------------------------

function clamp(n, min, max) {
  return Math.min(Math.max(n, min), max);
}

function applyLaunchFilter(list, filter) {
  if (!filter) return list;
  return list.filter((l) => {
    if (filter.status != null && l.status !== filter.status) return false;
    if (filter.rocketId != null && l.rocketId !== filter.rocketId) return false;
    if (filter.year != null && l.date.getUTCFullYear() !== filter.year) return false;
    if (filter.upcoming != null && l.upcoming !== filter.upcoming) return false;
    if (filter.favorite != null && l.favorite !== filter.favorite) return false;
    if (filter.search) {
      const needle = filter.search.toLowerCase();
      const inName = l.name.toLowerCase().includes(needle);
      const inDetails = l.details ? l.details.toLowerCase().includes(needle) : false;
      if (!inName && !inDetails) return false;
    }
    return true;
  });
}

function applyLaunchOrder(list, orderBy) {
  const sorted = [...list];
  switch (orderBy) {
    case "DATE_ASC":
      sorted.sort((a, b) => a.date.getTime() - b.date.getTime());
      break;
    case "NAME_ASC":
      sorted.sort((a, b) => a.name.localeCompare(b.name));
      break;
    case "DATE_DESC":
    default:
      sorted.sort((a, b) => b.date.getTime() - a.date.getTime());
      break;
  }
  return sorted;
}

function encodeCursor(index) {
  return Buffer.from(`cursor:${index}`, "utf8").toString("base64");
}

function decodeCursor(cursor) {
  let decoded;
  try {
    decoded = Buffer.from(cursor, "base64").toString("utf8");
  } catch {
    throw new GraphQLError(`Invalid cursor: ${cursor}`);
  }
  if (!decoded.startsWith("cursor:")) {
    throw new GraphQLError(`Invalid cursor: ${cursor}`);
  }
  const index = Number(decoded.slice("cursor:".length));
  if (!Number.isInteger(index) || index < 0) {
    throw new GraphQLError(`Invalid cursor: ${cursor}`);
  }
  return index;
}

function paginateCursor(list, { first, after, defaultFirst }) {
  const limit = clamp(first ?? defaultFirst, 1, 100);
  const startIndex = after != null ? decodeCursor(after) + 1 : 0;

  const slice = list.slice(startIndex, startIndex + limit);
  const edges = slice.map((node, i) => ({
    cursor: encodeCursor(startIndex + i),
    node,
  }));

  return {
    edges,
    nodes: slice,
    pageInfo: {
      hasNextPage: startIndex + limit < list.length,
      hasPreviousPage: startIndex > 0,
      startCursor: edges.length > 0 ? edges[0].cursor : null,
      endCursor: edges.length > 0 ? edges[edges.length - 1].cursor : null,
    },
    totalCount: list.length,
  };
}

function paginateOffset(list, { limit, offset }) {
  const l = clamp(limit ?? 20, 1, 100);
  const o = Math.max(0, offset ?? 0);
  return list.slice(o, o + l);
}

// ---------------------------------------------------------------------------
// Resolvers
// ---------------------------------------------------------------------------

export const resolvers = {
  DateTime,

  Query: {
    company: () => company,

    launches: (_root, { first, after, filter, orderBy }) => {
      const filtered = applyLaunchFilter(launches, filter);
      const ordered = applyLaunchOrder(filtered, orderBy ?? "DATE_DESC");
      return paginateCursor(ordered, { first, after, defaultFirst: 20 });
    },

    launchesPage: (_root, { limit, offset, filter, orderBy }) => {
      const filtered = applyLaunchFilter(launches, filter);
      const ordered = applyLaunchOrder(filtered, orderBy ?? "DATE_DESC");
      return paginateOffset(ordered, { limit, offset });
    },

    launch: (_root, { id }) => findLaunch(id) ?? null,

    nextLaunch: () => {
      const upcoming = launches.filter((l) => l.upcoming);
      if (upcoming.length === 0) return null;
      return upcoming.reduce((earliest, l) =>
        l.date.getTime() < earliest.date.getTime() ? l : earliest
      );
    },

    latestLaunch: () => {
      const past = launches.filter((l) => !l.upcoming);
      if (past.length === 0) return null;
      return past.reduce((latest, l) =>
        l.date.getTime() > latest.date.getTime() ? l : latest
      );
    },

    rockets: () => rockets,
    rocket: (_root, { id }) => findRocket(id) ?? null,

    launchpads: () => launchpads,

    astronauts: (_root, { first, after }) =>
      paginateCursor(astronauts, { first, after, defaultFirst: 20 }),
    astronaut: (_root, { id }) => findAstronaut(id) ?? null,

    me: () => ({
      id: 'viewer-1',
      name: 'Mira Vance',
      agency: 'Sling Space',
      avatarInitials: 'MV',
    }),

    stats: () => {
      const total = launches.length;
      const past = launches.filter((l) => !l.upcoming);
      const successes = past.filter((l) => l.status === "SUCCESS").length;
      const successRatePct =
        past.length > 0
          ? Math.round((successes / past.length) * 1000) / 10
          : 0;

      const perYear = new Map();
      for (const l of launches) {
        const year = l.date.getUTCFullYear();
        perYear.set(year, (perYear.get(year) ?? 0) + 1);
      }
      const launchesPerYear = [...perYear.entries()]
        .map(([year, count]) => ({ year, count }))
        .sort((a, b) => a.year - b.year);

      return { totalLaunches: total, successRatePct, launchesPerYear };
    },
  },

  Mutation: {
    toggleFavorite: (_root, { launchId }) => {
      const launch = toggleFavoriteData(launchId);
      if (!launch) {
        throw new GraphQLError(`Unknown launch id: ${launchId}`);
      }
      return launch;
    },

    scheduleLaunch: (_root, { input }, { pubsub }) => {
      if (!findRocket(input.rocketId)) {
        throw new GraphQLError(`Unknown rocket id: ${input.rocketId}`);
      }
      if (!findLaunchpad(input.launchpadId)) {
        throw new GraphQLError(`Unknown launchpad id: ${input.launchpadId}`);
      }
      const launch = scheduleLaunchData(input);
      pubsub.publish("launchScheduled", { launchScheduled: launch });
      return launch;
    },

    updateLaunchStatus: (_root, { id, status }, { pubsub }) => {
      const launch = updateLaunchStatusData(id, status);
      if (!launch) {
        throw new GraphQLError(`Unknown launch id: ${id}`);
      }
      pubsub.publish("launchStatusChanged", { launchStatusChanged: launch });
      return launch;
    },
  },

  Subscription: {
    launchStatusChanged: {
      subscribe: (_root, _args, { pubsub }) =>
        pubsub.subscribe("launchStatusChanged"),
      resolve: (payload) => payload.launchStatusChanged,
    },
    launchScheduled: {
      subscribe: (_root, _args, { pubsub }) =>
        pubsub.subscribe("launchScheduled"),
      resolve: (payload) => payload.launchScheduled,
    },
  },

  Rocket: {
    launches: (rocket, { first, after }) => {
      const ordered = launches
        .filter((l) => l.rocketId === rocket.id)
        .sort((a, b) => b.date.getTime() - a.date.getTime());
      return paginateCursor(ordered, { first, after, defaultFirst: 10 });
    },
  },

  Astronaut: {
    missions: (astronaut) =>
      launches.filter((l) => l.crewIds.includes(astronaut.id)),
  },

  Viewer: {
    favorites: () =>
      [...launches]
        .filter((l) => l.favorite === true)
        .sort((a, b) => b.date.getTime() - a.date.getTime()),
    favoriteCount: () => launches.filter((l) => l.favorite === true).length,
  },

  Launch: {
    rocket: (launch) => findRocket(launch.rocketId),
    launchpad: (launch) => findLaunchpad(launch.launchpadId),
    payloads: (launch) => launch.payloads,
    crew: (launch) => launch.crewIds.map((id) => findAstronaut(id)),
  },
};
