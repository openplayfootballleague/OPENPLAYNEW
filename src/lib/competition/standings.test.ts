import { describe, expect, it } from "vitest";
import { buildStandings, getJointFirstTeams } from "./standings";

describe("Open Play league standings", () => {
  it("shares positions for teams level on points regardless of goal difference", () => {
    const rows=buildStandings([{id:"alpha",name:"Alpha"},{id:"bravo",name:"Bravo"},{id:"charlie",name:"Charlie"}],
      [{id:"f1",home_team_id:"alpha",away_team_id:"charlie"},{id:"f2",home_team_id:"bravo",away_team_id:"charlie"}],
      [{fixture_id:"f1",home_score:5,away_score:0},{fixture_id:"f2",home_score:1,away_score:0}]);
    expect(rows.map(({id,position,points})=>({id,position,points}))).toEqual([
      {id:"alpha",position:1,points:3},{id:"bravo",position:1,points:3},{id:"charlie",position:3,points:0},
    ]);
    expect(rows[0].for-rows[0].against).toBeGreaterThan(rows[1].for-rows[1].against);
  });
  it("leaves a ranking gap after teams share a position", () => {
    const rows=buildStandings([{id:"a",name:"A"},{id:"b",name:"B"},{id:"c",name:"C"},{id:"d",name:"D"}],
      [{id:"a1",home_team_id:"a",away_team_id:"d"},{id:"b1",home_team_id:"b",away_team_id:"d"},{id:"c1",home_team_id:"c",away_team_id:"d"}],
      [{fixture_id:"a1",home_score:1,away_score:0},{fixture_id:"b1",home_score:2,away_score:0},{fixture_id:"c1",home_score:3,away_score:0}]);
    expect(rows.map(({id,position})=>[id,position])).toEqual([["a",1],["b",1],["c",1],["d",4]]);
  });
  it("does not count fixtures without a result", () => {
    const rows=buildStandings([{id:"a",name:"A"},{id:"b",name:"B"}],[{id:"f1",home_team_id:"a",away_team_id:"b"}],[]);
    expect(rows.map(({played,points})=>[played,points])).toEqual([[0,0],[0,0]]);
  });
});

describe("Open Play tied first-place final", () => {
  it("identifies all teams sharing first place so a final can be scheduled", () => {
    const leaders = getJointFirstTeams([
      { team_id: "alpha", name: "Alpha", position: 1 },
      { team_id: "bravo", name: "Bravo", position: 1 },
      { team_id: "charlie", name: "Charlie", position: 3 },
    ]);
    expect(leaders.map((team) => team.name)).toEqual(["Alpha", "Bravo"]);
  });

  it("does not request a final when first place is not tied", () => {
    expect(getJointFirstTeams([
      { name: "Alpha", position: 1 },
      { name: "Bravo", position: 2 },
    ])).toEqual([]);
  });
});

describe("Open Play title final (owner decision D7)", () => {
  it("does not add a title final's result to league points", () => {
    const rows = buildStandings([{id:"a",name:"A"},{id:"b",name:"B"}],
      [{id:"l1",home_team_id:"a",away_team_id:"b"},{id:"final",home_team_id:"a",away_team_id:"b",is_title_final:true}],
      [{fixture_id:"l1",home_score:1,away_score:1},{fixture_id:"final",home_score:3,away_score:0}]);
    expect(rows.map(({id,played,points,position})=>[id,played,points,position])).toEqual([["a",1,1,1],["b",1,1,1]]);
  });

  it("does not report a title tie before any team has a point", () => {
    const rows = buildStandings([{id:"a",name:"A"},{id:"b",name:"B"}],[],[]);
    expect(rows.every((row)=>row.position===1)).toBe(true);
    expect(getJointFirstTeams(rows)).toEqual([]);
  });
});

