import * as userService from "../services/userServices.js";

export const getUsers = async (): Promise<Response> => {
  try {
    const users = await userService.getUsers();
    return Response.json(users, { status: 200 });
  } catch (err) {
    console.error("Error Fetching users", err);
    return Response.json(
      { message: "Internal server error, Can't get users" },
      { status: 500 },
    );
  }
};
