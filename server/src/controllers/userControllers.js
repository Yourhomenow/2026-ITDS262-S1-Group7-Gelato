import * as userService from "../services/userServices.js"

export const getUsers = async (req, res)=>{
  try{
    const user = await userService.getUsers();
    res.status(200).json(user)
  }catch(err){
    console.error(`Error Fetching users`, err)
    res.status(500).json({message: "Internal server error, Can't get users"})
  }
}